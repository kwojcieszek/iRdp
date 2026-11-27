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
    let staticChannelIds: [String: UInt16]

    private init(channel: any Channel, inbox: FrameInbox, group: MultiThreadedEventLoopGroup, userId: UInt16, staticChannelIds: [String: UInt16] = [:]) {
        self.channel = channel
        self.inbox = inbox
        self.group = group
        self.userId = userId
        self.staticChannelIds = staticChannelIds
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
    func connectSession(userName: String, password: String, width: UInt16 = 800, height: UInt16 = 600, supportsGraphicsPipeline: Bool = false, extraChannels: [String] = []) async throws -> RdpTestClient {
        var tls = TLSConfiguration.makeClientConfiguration()
        tls.certificateVerification = .none
        let sslContext = try NIOSSLContext(configuration: tls)
        try await channel.eventLoop.submit {
            try self.channel.pipeline.syncOperations.addHandler(try NIOSSLClientHandler(context: sslContext, serverHostname: nil), position: .first)
        }.get()

        let clientData = ClientConnectionData(
            core: ClientCoreData(desktopWidth: width, desktopHeight: height, clientName: "TESTCLIENT", earlyCapabilityFlags: ClientCoreData.wants32BitsPerPixelSession | (supportsGraphicsPipeline ? ClientCoreData.supportsGraphicsPipeline : 0)),
            network: ClientNetworkData(channels: [ChannelDefinition(name: "cliprdr")] + (supportsGraphicsPipeline ? [ChannelDefinition(name: "drdynvc")] : []) + extraChannels.map { ChannelDefinition(name: $0) })
        )
        try await send(X224DataTpdu.packet(McsConnectInitial(userData: GccConferenceCreateRequest.encode(clientData: clientData.encodeBlocks())).encode()))
        let response = try McsConnectResponse.parse(X224DataTpdu.payload(of: TpktPacket.unwrap(try await nextFrame())))
        let serverData = try ServerConnectionData.parse(GccConferenceCreateResponse.parse(response.userData))

        try await send(X224DataTpdu.packet(McsDomainPdu.erectDomainRequest.encode()))
        try await send(X224DataTpdu.packet(McsDomainPdu.attachUserRequest.encode()))
        guard case .attachUserConfirm(0, let userId) = try await nextDomainPdu() else { throw RdpTestClientError.unexpected("attach user confirm") }
        let names = clientData.network.channels.map(\.name)
        let session = RdpTestClient(channel: channel, inbox: inbox, group: group, userId: userId, staticChannelIds: Dictionary(uniqueKeysWithValues: zip(names, serverData.staticChannelIds)))
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

    // MARK: - Graphics pipeline

    /// Answers the DVC handshake, advertises graphics capabilities and returns the server's setup commands.
    func openGraphicsPipeline(capabilities: [GraphicsCapabilitySet]) async throws -> [UInt16] {
        guard case .capabilities = try await nextDynamicChannelPdu() else { throw RdpTestClientError.unexpected("DVC capabilities") }
        try await sendDynamicChannelPdu(.capabilities(version: 1))
        guard case .createRequest(let id, let name) = try await nextDynamicChannelPdu(), name == "Microsoft::Windows::RDS::Graphics" else { throw RdpTestClientError.unexpected("create request") }
        try await sendDynamicChannelPdu(.createResponse(channelId: id, status: 0))
        try await sendDynamicChannelPdu(.data(channelId: id, data: GraphicsClientPdu.capsAdvertise(capabilities).encode()))
        return try Self.commands(in: try await nextGraphicsMessage())
    }

    func sendFrameAcknowledge(frameId: UInt32) async throws {
        try await sendDynamicChannelPdu(.data(channelId: 1, data: GraphicsClientPdu.frameAcknowledge(queueDepth: 0, frameId: frameId, totalFramesDecoded: frameId).encode()))
    }

    private var dynamicChannelId: UInt16 { staticChannelIds["drdynvc"] ?? 0 }

    func sendDynamicChannelPdu(_ pdu: DynamicChannelPdu) async throws {
        for chunk in StaticChannelPdu.chunks(for: pdu.encode()) {
            try await send(X224DataTpdu.packet(McsDomainPdu.sendDataRequest(userId: userId, channelId: dynamicChannelId, data: chunk).encode()))
        }
    }

    func nextDynamicChannelPdu() async throws -> DynamicChannelPdu {
        var reassembler = StaticChannelReassembler()
        while true {
            let frame = try await nextFrame()
            guard frame.first == TpktPacket.version,
                  case .sendDataIndication(_, let channelId, let data) = try McsDomainPdu.parse(X224DataTpdu.payload(of: TpktPacket.unwrap(frame))),
                  channelId == dynamicChannelId,
                  let message = try reassembler.append(data) else { continue }
            return try DynamicChannelPdu.parse(message)
        }
    }

    /// Next complete RDPGFX message (unwrapped from segmented data).
    func nextGraphicsMessage() async throws -> [UInt8] {
        var reassembler = DynamicChannelReassembler()
        while true {
            if let (_, message) = reassembler.append(try await nextDynamicChannelPdu()) {
                return try SegmentedData.unwrap(message)
            }
        }
    }

    static func commands(in message: [UInt8]) throws -> [UInt16] {
        var reader = ByteReader(message)
        var result: [UInt16] = []
        while reader.remaining >= 8 {
            result.append(try reader.readUInt16LE())
            _ = try reader.readUInt16LE()
            try reader.skip(Int(try reader.readUInt32LE()) - 8)
        }
        return result
    }

    // MARK: - Static channels

    func sendStaticChannelMessage(_ message: [UInt8], channel name: String) async throws {
        guard let channelId = staticChannelIds[name] else { throw RdpTestClientError.unexpected("channel \(name)") }
        for chunk in StaticChannelPdu.chunks(for: message) {
            try await send(X224DataTpdu.packet(McsDomainPdu.sendDataRequest(userId: userId, channelId: channelId, data: chunk).encode()))
        }
    }

    /// Next complete message the server sent on a static channel, skipping other traffic.
    func nextStaticChannelMessage(channel name: String) async throws -> [UInt8] {
        guard let channelId = staticChannelIds[name] else { throw RdpTestClientError.unexpected("channel \(name)") }
        var reassembler = StaticChannelReassembler()
        while true {
            let frame = try await nextFrame()
            guard frame.first == TpktPacket.version,
                  case .sendDataIndication(_, channelId, let data) = try McsDomainPdu.parse(X224DataTpdu.payload(of: TpktPacket.unwrap(frame))),
                  let message = try reassembler.append(data) else { continue }
            return message
        }
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
