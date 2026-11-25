import Foundation
import NIOCore
import NIOSSL
import os
import RdpProtocol

/// Drives one RDP connection: negotiation, TLS upgrade, MCS/GCC, licensing, capability exchange and the active session.
final class RdpConnectionHandler: ChannelInboundHandler {
    typealias InboundIn = RdpInboundFrame
    typealias OutboundOut = ByteBuffer

    private static let logger = Logger(subsystem: "com.kwojcieszek.irdp", category: "connection")
    static let shareId: UInt32 = 0x0001_03EA

    private let configuration: RdpServerConfiguration
    private let environment: RdpSessionEnvironment
    private let sslContext: NIOSSLContext
    private let registry: RdpSessionRegistry
    private let sessionId = UUID()

    private var context: ChannelHandlerContext?
    private var phase: RdpConnectionPhase = .awaitingConnectionRequest
    private var remoteAddress = "unknown"
    private var requestedProtocols: SecurityProtocols = []
    private var clientData: ClientConnectionData?
    private var userId: UInt16 = 1007
    private var staticChannelIds: [UInt16] = []
    private var clientInfo: ClientInfoPacket?
    private var resources: RdpSessionResources?
    private var desktopSize = DesktopSize(width: 0, height: 0)
    private var bitsPerPixel = 32
    private var clientSupportsCompressionWithoutHeader = false
    private var pump: FrameUpdatePump?
    private var isRegistered = false

    init(configuration: RdpServerConfiguration, environment: RdpSessionEnvironment, sslContext: NIOSSLContext, registry: RdpSessionRegistry) {
        self.configuration = configuration
        self.environment = environment
        self.sslContext = sslContext
        self.registry = registry
    }

    // MARK: - Channel events

    func handlerAdded(context: ChannelHandlerContext) {
        self.context = context
        remoteAddress = context.channel.remoteAddress?.ipAddress ?? "unknown"
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let frame = unwrapInboundIn(data)
        do {
            switch frame.kind {
            case .tpkt:
                try handleTpkt(TpktPacket.unwrap(frame.bytes))
            case .fastPath:
                try handleFastPathInput(frame.bytes)
            }
        } catch {
            fail("protocol error: \(error)")
        }
    }

    func channelInactive(context: ChannelHandlerContext) {
        tearDown()
        context.fireChannelInactive()
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        fail("connection error: \(error)")
    }

    // MARK: - TPKT dispatch

    private func handleTpkt(_ payload: [UInt8]) throws {
        switch phase {
        case .awaitingConnectionRequest:
            try handleConnectionRequest(X224ConnectionRequest.parse(payload))
        case .awaitingConnectInitial:
            try handleConnectInitial(McsConnectInitial.parse(X224DataTpdu.payload(of: payload)))
        case .closed:
            return
        default:
            let mcs = try X224DataTpdu.payload(of: payload)
            try handleDomainPdu(McsDomainPdu.parse(mcs))
        }
    }

    private func handleConnectionRequest(_ request: X224ConnectionRequest) throws {
        requestedProtocols = request.requestedProtocols
        guard request.requestedProtocols.contains(.tls) else {
            Self.logger.notice("client \(self.remoteAddress, privacy: .public) does not offer TLS (\(request.requestedProtocols.rawValue))")
            send(TpktPacket.wrap(X224ConnectionConfirm(outcome: .failure(.sslRequiredByServer)).encode()))
            fail("client does not support TLS")
            return
        }
        send(TpktPacket.wrap(X224ConnectionConfirm(outcome: .selected(.tls, flags: X224ConnectionConfirm.extendedClientDataSupported)).encode()))
        guard let context else { return }
        try context.pipeline.syncOperations.addHandler(NIOSSLServerHandler(context: sslContext), position: .first)
        phase = .awaitingConnectInitial
    }

    private func handleConnectInitial(_ initial: McsConnectInitial) throws {
        let data = try ClientConnectionData.parse(GccConferenceCreateRequest.parse(initial.userData))
        clientData = data
        staticChannelIds = data.network.channels.indices.map { McsChannel.firstStaticChannelId + UInt16($0) }
        userId = max(1007, McsChannel.firstStaticChannelId + UInt16(staticChannelIds.count))
        let serverData = ServerConnectionData(version: configuration.serverVersion, clientRequestedProtocols: requestedProtocols, staticChannelIds: staticChannelIds)
        let response = McsConnectResponse(userData: GccConferenceCreateResponse.encode(serverData: serverData.encodeBlocks()))
        send(X224DataTpdu.packet(response.encode()))
        phase = .channelConnection
        Self.logger.info("client \(data.core.clientName, privacy: .public) requested \(data.core.desktopWidth)x\(data.core.desktopHeight), \(data.network.channels.count) channels")
    }

    private func handleDomainPdu(_ pdu: McsDomainPdu) throws {
        switch pdu {
        case .erectDomainRequest:
            break
        case .attachUserRequest:
            sendMcs(.attachUserConfirm(result: 0, userId: userId))
        case .channelJoinRequest(_, let channelId):
            sendMcs(.channelJoinConfirm(result: 0, userId: userId, requestedChannelId: channelId, channelId: channelId))
            if phase == .channelConnection { phase = .awaitingClientInfo }
        case .sendDataRequest(_, let channelId, let data):
            guard channelId == McsChannel.ioChannelId else { return }
            try handleIoChannelData(data)
        case .disconnectProviderUltimatum:
            close()
        default:
            throw RdpProtocolError.unsupported("unexpected MCS PDU \(pdu)")
        }
    }

    // MARK: - I/O channel

    private func handleIoChannelData(_ data: [UInt8]) throws {
        switch phase {
        case .awaitingClientInfo:
            let info = try ClientInfoPacket.parse(data)
            clientInfo = info
            authenticate(info)
        case .authenticating, .closed:
            return
        default:
            for pdu in try SharePdu.parseAll(data) {
                try handleSharePdu(pdu)
            }
        }
    }

    private func authenticate(_ info: ClientInfoPacket) {
        guard let context else { return }
        phase = .authenticating
        let credentials = ClientCredentials(userName: info.userName, domain: info.domain, password: info.password)
        let environment = environment
        let bound = NIOLoopBound(self, eventLoop: context.eventLoop)
        let eventLoop = context.eventLoop
        Task {
            let isValid = await environment.credentialValidator.validate(credentials)
            var result: Result<RdpSessionResources, any Error>?
            if isValid {
                do {
                    result = .success(try await environment.makeSessionResources())
                } catch {
                    result = .failure(error)
                }
            }
            let outcome = result
            eventLoop.execute {
                bound.value.authenticationFinished(isValid: isValid, resources: outcome)
            }
        }
    }

    private func authenticationFinished(isValid: Bool, resources result: Result<RdpSessionResources, any Error>?) {
        guard phase == .authenticating else {
            if case .success(let resources) = result { Task { await resources.frameSource.stop() } }
            return
        }
        sendMcs(.sendDataIndication(userId: userId, channelId: McsChannel.ioChannelId, data: LicenseErrorMessage.validClient()))
        guard isValid else {
            Self.logger.notice("authentication failed for user \(self.clientInfo?.userName ?? "", privacy: .public) from \(self.remoteAddress, privacy: .public)")
            disconnect(errorInfo: SetErrorInfoPdu.serverDeniedConnection, reason: "authentication failed")
            return
        }
        switch result {
        case .success(let resources)?:
            self.resources = resources
            desktopSize = resources.frameSource.desktopSize
            bitsPerPixel = negotiateBitsPerPixel()
            let capabilities = ServerCapabilities.make(desktopWidth: UInt16(desktopSize.width), desktopHeight: UInt16(desktopSize.height), bitsPerPixel: UInt16(bitsPerPixel))
            sendShareControl(.demandActive, body: DemandActivePdu(shareId: Self.shareId, capabilities: capabilities).encode())
            phase = .awaitingConfirmActive
        case .failure(let error)?:
            disconnect(errorInfo: SetErrorInfoPdu.serverDeniedConnection, reason: "cannot share the screen: \(error)")
        case nil:
            disconnect(errorInfo: SetErrorInfoPdu.serverDeniedConnection, reason: "no session resources")
        }
    }

    private func negotiateBitsPerPixel() -> Int {
        let preferred = configuration.preferredBitsPerPixel
        guard let core = clientData?.core else { return 16 }
        let supported = core.supportedColorDepths ?? 0
        let wants32 = (core.earlyCapabilityFlags ?? 0) & ClientCoreData.wants32BitsPerPixelSession != 0
        if preferred >= 32, supported & ClientCoreData.supports32BitsPerPixel != 0, wants32 { return 32 }
        let clientDepth = Int(core.highColorDepth ?? 16)
        return [24, 16].first { $0 <= min(preferred, max(clientDepth, 16)) } ?? 16
    }

    // MARK: - Share PDUs

    private func handleSharePdu(_ pdu: SharePdu) throws {
        switch pdu.type {
        case .confirmActive:
            try handleConfirmActive(ConfirmActivePdu.parse(pdu.body))
        case .data:
            guard let type = pdu.dataType else { return }
            try handleDataPdu(type, body: pdu.body)
        default:
            break
        }
    }

    private func handleConfirmActive(_ confirm: ConfirmActivePdu) throws {
        if let bitmap = confirm.capability(CapabilitySetType.bitmap).flatMap({ try? BitmapCapability.parse($0.body) }),
           [16, 24, 32].contains(Int(bitmap.preferredBitsPerPixel)) {
            bitsPerPixel = Int(bitmap.preferredBitsPerPixel)
        }
        if let general = confirm.capability(CapabilitySetType.general).flatMap({ try? GeneralCapability.parse($0.body) }) {
            clientSupportsCompressionWithoutHeader = general.extraFlags & GeneralCapability.noBitmapCompressionHeader != 0
            if !general.supportsFastPathOutput { Self.logger.warning("client does not announce fast-path output support") }
        }
        phase = .finalizing
    }

    private func handleDataPdu(_ type: ShareDataPduType, body: [UInt8]) throws {
        switch type {
        case .synchronize:
            sendShareData(.synchronize, body: SynchronizePdu(targetUser: McsChannel.serverChannelId).encode())
        case .control:
            let control = try ControlPdu.parse(body)
            switch control.action {
            case .cooperate:
                sendShareData(.control, body: ControlPdu(action: .cooperate).encode())
            case .requestControl:
                sendShareData(.control, body: ControlPdu(action: .grantedControl, grantId: userId, controlId: UInt32(McsChannel.serverChannelId)).encode())
            default:
                break
            }
        case .fontList:
            sendShareData(.fontMap, body: FontMapPdu.encode())
            if phase == .finalizing { activate() }
        case .input:
            dispatch(try SlowPathInputPdu.parse(body))
        case .refreshRect:
            pump?.requestFullRefresh()
        case .suppressOutput:
            pump?.setPaused(!(try SuppressOutputPdu.parse(body).allowDisplayUpdates))
        case .shutdownRequest:
            close()
        default:
            break
        }
    }

    private func handleFastPathInput(_ bytes: [UInt8]) throws {
        guard phase == .active else { return }
        dispatch(try FastPathInputPdu.parse(bytes))
    }

    private func dispatch(_ events: [RdpInputEvent]) {
        guard phase == .active, let sink = resources?.inputSink else { return }
        events.forEach { sink.handle($0) }
    }

    // MARK: - Active session

    private func activate() {
        guard let context, let resources else { return }
        phase = .active
        send(FastPathUpdate.pdu([FastPathUpdate(code: .defaultPointer)]))
        let channel = context.channel
        let pump = FrameUpdatePump(encoder: ScreenUpdateEncoder(bitsPerPixel: bitsPerPixel, includesCompressionHeader: !clientSupportsCompressionWithoutHeader)) { pdus, completion in
            channel.eventLoop.execute {
                var lastWrite: EventLoopFuture<Void>?
                for pdu in pdus {
                    var buffer = channel.allocator.buffer(capacity: pdu.count)
                    buffer.writeBytes(pdu)
                    lastWrite = channel.write(buffer)
                }
                channel.flush()
                if let lastWrite {
                    lastWrite.whenComplete { _ in completion() }
                } else {
                    completion()
                }
            }
        }
        self.pump = pump
        let bound = NIOLoopBound(self, eventLoop: context.eventLoop)
        let eventLoop = context.eventLoop
        let replaced = registry.register(sessionId, maximumSessions: configuration.maximumSessions) {
            eventLoop.execute { bound.value.disconnect(errorInfo: SetErrorInfoPdu.disconnectedByOtherConnection, reason: "replaced by a new session") }
        }
        isRegistered = true
        replaced.forEach { $0() }
        let info = RdpSessionInfo(id: sessionId, remoteAddress: remoteAddress, clientName: clientData?.core.clientName ?? "", userName: clientInfo?.userName ?? "", desktopSize: desktopSize, bitsPerPixel: bitsPerPixel, startedAt: Date())
        environment.observer?.sessionDidStart(info)
        Self.logger.info("session started for \(info.userName, privacy: .public) at \(info.desktopSize.width)x\(info.desktopSize.height)@\(info.bitsPerPixel)bpp")
        let frameSource = resources.frameSource
        Task {
            do {
                try await frameSource.start { frame in pump.submit(frame) }
            } catch {
                eventLoop.execute { bound.value.disconnect(errorInfo: SetErrorInfoPdu.serverDeniedConnection, reason: "screen capture failed: \(error)") }
            }
        }
    }

    // MARK: - Output helpers

    private func send(_ bytes: [UInt8]) {
        guard let context else { return }
        var buffer = context.channel.allocator.buffer(capacity: bytes.count)
        buffer.writeBytes(bytes)
        context.writeAndFlush(wrapOutboundOut(buffer), promise: nil)
    }

    private func sendMcs(_ pdu: McsDomainPdu) {
        send(X224DataTpdu.packet(pdu.encode()))
    }

    private func sendShareControl(_ type: ShareControlPduType, body: [UInt8]) {
        let data = SharePdu.encodeControl(type: type, source: McsChannel.serverChannelId, body: body)
        sendMcs(.sendDataIndication(userId: userId, channelId: McsChannel.ioChannelId, data: data))
    }

    private func sendShareData(_ type: ShareDataPduType, body: [UInt8]) {
        let data = SharePdu.encodeData(type: type, shareId: Self.shareId, source: McsChannel.serverChannelId, body: body)
        sendMcs(.sendDataIndication(userId: userId, channelId: McsChannel.ioChannelId, data: data))
    }

    // MARK: - Teardown

    func disconnect(errorInfo: UInt32, reason: String) {
        guard phase != .closed else { return }
        Self.logger.notice("disconnecting \(self.remoteAddress, privacy: .public): \(reason, privacy: .public)")
        if phase != .active { environment.observer?.connectionDidFail(remoteAddress: remoteAddress, reason: reason) }
        sendShareData(.setErrorInfo, body: SetErrorInfoPdu(errorInfo: errorInfo).encode())
        close()
    }

    private func fail(_ reason: String) {
        guard phase != .closed else { return }
        Self.logger.error("closing \(self.remoteAddress, privacy: .public): \(reason, privacy: .public)")
        if phase != .active { environment.observer?.connectionDidFail(remoteAddress: remoteAddress, reason: reason) }
        close()
    }

    private func close() {
        guard let context else { return }
        if phase != .closed, phase != .awaitingConnectionRequest, phase != .awaitingConnectInitial {
            sendMcs(.disconnectProviderUltimatum)
        }
        tearDown()
        context.close(promise: nil)
    }

    private func tearDown() {
        let wasActive = phase == .active
        phase = .closed
        pump?.stop()
        pump = nil
        if let resources {
            resources.inputSink?.releaseAll()
            let frameSource = resources.frameSource
            Task { await frameSource.stop() }
            self.resources = nil
        }
        if isRegistered {
            registry.unregister(sessionId)
            isRegistered = false
        }
        if wasActive { environment.observer?.sessionDidEnd(sessionId) }
    }
}
