import NIOCore
import NIOPosix
import NIOSSL
import RdpProtocol

/// Minimal RDP client used to exercise the server end to end.
final class RdpTestClient: Sendable {
    let channel: any Channel
    private let inbox: FrameInbox
    private let group: MultiThreadedEventLoopGroup
    let userId: UInt16

    private init(channel: any Channel, inbox: FrameInbox, group: MultiThreadedEventLoopGroup, userId: UInt16) {
        self.channel = channel
        self.inbox = inbox
        self.group = group
        self.userId = userId
    }

    /// Connects and runs the protocol until the server answers the X.224 connection request.
    static func connect(host: String = "127.0.0.1", port: Int, requestedProtocols: SecurityProtocols = [.tls, .credSsp]) async throws -> (RdpTestClient, X224ConnectionConfirm) {
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let (stream, continuation) = AsyncStream<[UInt8]>.makeStream()
        let channel = try await ClientBootstrap(group: group)
            .channelInitializer { channel in
                channel.eventLoop.makeCompletedFuture {
                    try channel.pipeline.syncOperations.addHandler(ByteToMessageHandler(TestFrameDecoder()))
                    try channel.pipeline.syncOperations.addHandler(FrameCollector(continuation: continuation))
                }
            }
            .connect(host: host, port: port).get()
        let client = RdpTestClient(channel: channel, inbox: FrameInbox(stream: stream), group: group, userId: 0)
        try await client.send(TpktPacket.wrap(X224ConnectionRequest(cookie: "mstshash=test", requestedProtocols: requestedProtocols).encode()))
        let confirm = try X224ConnectionConfirm.parse(TpktPacket.unwrap(try await client.nextFrame()))
        return (client, confirm)
    }

    /// Performs TLS and the MCS connection sequence, then sends the client info PDU.
    func connectSession(userName: String, password: String, width: UInt16 = 800, height: UInt16 = 600) async throws -> RdpTestClient {
        var tls = TLSConfiguration.makeClientConfiguration()
        tls.certificateVerification = .none
        let sslContext = try NIOSSLContext(configuration: tls)
        try await channel.eventLoop.submit {
            try self.channel.pipeline.syncOperations.addHandler(try NIOSSLClientHandler(context: sslContext, serverHostname: nil), position: .first)
        }.get()

        let clientData = ClientConnectionData(
            core: ClientCoreData(desktopWidth: width, desktopHeight: height, clientName: "TESTCLIENT", earlyCapabilityFlags: ClientCoreData.wants32BitsPerPixelSession),
            network: ClientNetworkData(channels: [ChannelDefinition(name: "cliprdr")])
        )
        try await send(X224DataTpdu.packet(McsConnectInitial(userData: GccConferenceCreateRequest.encode(clientData: clientData.encodeBlocks())).encode()))
        let response = try McsConnectResponse.parse(X224DataTpdu.payload(of: TpktPacket.unwrap(try await nextFrame())))
        let serverData = try ServerConnectionData.parse(GccConferenceCreateResponse.parse(response.userData))

        try await send(X224DataTpdu.packet(McsDomainPdu.erectDomainRequest.encode()))
        try await send(X224DataTpdu.packet(McsDomainPdu.attachUserRequest.encode()))
        guard case .attachUserConfirm(0, let userId) = try await nextDomainPdu() else { throw RdpTestClientError.unexpected("attach user confirm") }
        let session = RdpTestClient(channel: channel, inbox: inbox, group: group, userId: userId)
        for channelId in [userId, serverData.ioChannelId] + serverData.staticChannelIds {
            try await send(X224DataTpdu.packet(McsDomainPdu.channelJoinRequest(userId: userId, channelId: channelId).encode()))
            guard case .channelJoinConfirm(0, _, _, channelId) = try await nextDomainPdu() else { throw RdpTestClientError.unexpected("join \(channelId)") }
        }
        try await session.sendIo(ClientInfoPacket(userName: userName, password: password).encode())
        return session
    }

    /// Answers the Demand Active PDU and runs the finalization sequence. Returns the server's bitmap capability.
    func activate(bitsPerPixel: UInt16 = 32) async throws -> BitmapCapability {
        var demand: DemandActivePdu?
        while demand == nil {
            let data = try await nextIoData()
            if data.starts(with: LicenseErrorMessage.validClient().prefix(2)) { continue }
            for pdu in try SharePdu.parseAll(data) where pdu.type == .demandActive {
                demand = try DemandActivePdu.parse(pdu.body)
            }
        }
        guard let demand, let serverBitmap = demand.capabilities.first(where: { $0.type == CapabilitySetType.bitmap }) else {
            throw RdpTestClientError.unexpected("demand active")
        }
        let bitmap = try BitmapCapability.parse(serverBitmap.body)
        let capabilities = [
            GeneralCapability(extraFlags: GeneralCapability.fastPathOutputSupported).encode(),
            BitmapCapability(preferredBitsPerPixel: bitsPerPixel, desktopWidth: bitmap.desktopWidth, desktopHeight: bitmap.desktopHeight).encode(),
            InputCapability.serverDefault.encode(),
        ]
        try await sendIo(SharePdu.encodeControl(type: .confirmActive, source: userId, body: ConfirmActivePdu(shareId: demand.shareId, capabilities: capabilities).encode()))
        try await sendData(.synchronize, shareId: demand.shareId, body: SynchronizePdu(targetUser: McsChannel.serverChannelId).encode())
        try await sendData(.control, shareId: demand.shareId, body: ControlPdu(action: .cooperate).encode())
        try await sendData(.control, shareId: demand.shareId, body: ControlPdu(action: .requestControl).encode())
        try await sendData(.fontList, shareId: demand.shareId, body: FontListPdu.encode())
        var receivedFontMap = false
        while !receivedFontMap {
            receivedFontMap = try SharePdu.parseAll(try await nextIoData()).contains { $0.dataType == .fontMap }
        }
        return bitmap
    }

    // MARK: - Low level helpers

    func send(_ bytes: [UInt8]) async throws {
        var buffer = channel.allocator.buffer(capacity: bytes.count)
        buffer.writeBytes(bytes)
        try await channel.writeAndFlush(buffer)
    }

    func sendIo(_ data: [UInt8]) async throws {
        try await send(X224DataTpdu.packet(McsDomainPdu.sendDataRequest(userId: userId, channelId: McsChannel.ioChannelId, data: data).encode()))
    }

    func sendData(_ type: ShareDataPduType, shareId: UInt32, body: [UInt8]) async throws {
        try await sendIo(SharePdu.encodeData(type: type, shareId: shareId, source: userId, body: body))
    }

    func nextFrame() async throws -> [UInt8] {
        guard let frame = await inbox.next() else { throw RdpTestClientError.connectionClosed }
        return frame
    }

    func nextDomainPdu() async throws -> McsDomainPdu {
        try McsDomainPdu.parse(X224DataTpdu.payload(of: TpktPacket.unwrap(try await nextFrame())))
    }

    /// Next data sent by the server on the I/O channel, skipping fast-path frames.
    func nextIoData() async throws -> [UInt8] {
        while true {
            let frame = try await nextFrame()
            guard frame.first == TpktPacket.version else { continue }
            switch try McsDomainPdu.parse(X224DataTpdu.payload(of: TpktPacket.unwrap(frame))) {
            case .sendDataIndication(_, McsChannel.ioChannelId, let data):
                return data
            case .disconnectProviderUltimatum:
                throw RdpTestClientError.connectionClosed
            default:
                continue
            }
        }
    }

    /// Next fast-path output PDU, skipping slow-path frames.
    func nextFastPathUpdates() async throws -> [FastPathUpdate] {
        while true {
            let frame = try await nextFrame()
            if frame.first != TpktPacket.version { return try FastPathUpdate.parsePdu(frame) }
        }
    }

    func close() async {
        try? await channel.close()
        try? await group.shutdownGracefully()
    }
}
