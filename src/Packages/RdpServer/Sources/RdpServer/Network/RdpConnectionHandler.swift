import Foundation
import NIOCore
import NIOSSL
import os
import RdpProtocol

/// Drives one RDP connection: negotiation, TLS upgrade, MCS/GCC, licensing, capability exchange and the active session.
final class RdpConnectionHandler: ChannelInboundHandler {
    typealias InboundIn = RdpInboundFrame
    typealias OutboundOut = ByteBuffer

    private static let logger = Logger(subsystem: "com.irdp", category: "connection")
    static let shareId: UInt32 = 0x0001_03EA

    private let configuration: RdpServerConfiguration
    private let environment: RdpSessionEnvironment
    private let sslContext: NIOSSLContext
    private let registry: RdpSessionRegistry
    private let throttle: AuthenticationThrottle
    private let quality: StreamingQualityHolder
    private let framing: RdpFramingState
    private var credSsp: CredSspServer?
    /// User authenticated by network level authentication; the Client Info credentials are then not needed.
    private var networkAuthenticatedUser: String?
    private var selectedProtocol: SecurityProtocols = .tls
    /// RDP frames that arrive while the CredSSP credentials are still being verified.
    private var framesAwaitingAuthentication: [RdpInboundFrame] = []
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
    private var clientSupportsScreenCopy = false
    private var clientSupportsCompressionWithoutHeader = false
    private var pump: FrameUpdatePump?
    private var isRegistered = false
    private var logonForm: LogonForm?
    /// Set only after the credentials were verified; input and screen capture require it.
    private var isAuthenticated = false
    /// Receives input only while an authenticated desktop session runs.
    private var authenticatedInputSink: (any InputSink)?
    private var logonRenderer: LogonScreenRenderer?
    private var drdynvcChannelId: UInt16?
    private var graphicsChannel = GraphicsChannelController()
    private var rdpsndChannelId: UInt16?
    private var audioChannel = AudioChannelController()
    private var isAudioStreaming = false
    private let audioClock = ContinuousClock()
    private lazy var audioClockStart = audioClock.now
    private var virtualChannelChunkLength = StaticChannelPdu.defaultChunkLength
    private var keyTranslator = KeyboardTextTranslator(keyboardLayout: 0)

    init(configuration: RdpServerConfiguration, environment: RdpSessionEnvironment, sslContext: NIOSSLContext, registry: RdpSessionRegistry, throttle: AuthenticationThrottle, quality: StreamingQualityHolder, framing: RdpFramingState) {
        self.configuration = configuration
        self.environment = environment
        self.sslContext = sslContext
        self.registry = registry
        self.throttle = throttle
        self.quality = quality
        self.framing = framing
    }

    // MARK: - Channel events

    func handlerAdded(context: ChannelHandlerContext) {
        self.context = context
        remoteAddress = RemoteAddressFormatter.string(for: context.channel.remoteAddress)
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        process(unwrapInboundIn(data))
    }

    private func process(_ frame: RdpInboundFrame) {
        if phase == .credSsp, frame.kind != .credSsp {
            framesAwaitingAuthentication.append(frame)
            return
        }
        do {
            switch frame.kind {
            case .tpkt:
                try handleTpkt(TpktPacket.unwrap(frame.bytes))
            case .fastPath:
                try handleFastPathInput(frame.bytes)
            case .credSsp:
                handleCredSsp(frame.bytes)
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
        var flags = X224ConnectionConfirm.extendedClientDataSupported
        if configuration.usesGraphicsPipeline { flags |= X224ConnectionConfirm.dynamicVirtualChannelGraphicsSupported }
        if configuration.requiresNetworkLevelAuthentication {
            if request.requestedProtocols.contains(.credSsp) {
                selectedProtocol = .credSsp
            } else if request.requestedProtocols.contains(.credSspWithEarlyUserAuthorization) {
                selectedProtocol = .credSspWithEarlyUserAuthorization
            } else {
                Self.logger.notice("client \(self.remoteAddress, privacy: .public) does not support network level authentication")
                send(TpktPacket.wrap(X224ConnectionConfirm(outcome: .failure(.hybridRequiredByServer)).encode()))
                fail("client does not support network level authentication")
                return
            }
        }
        send(TpktPacket.wrap(X224ConnectionConfirm(outcome: .selected(selectedProtocol, flags: flags)).encode()))
        guard let context else { return }
        try context.pipeline.syncOperations.addHandler(NIOSSLServerHandler(context: sslContext), position: .first)
        if selectedProtocol == .tls {
            phase = .awaitingConnectInitial
        } else {
            let publicKey = try SubjectPublicKey.of(certificatePEM: configuration.certificate.certificatePEM)
            credSsp = CredSspServer(publicKey: publicKey, computerName: Self.netBiosName(configuration.serverName), ntHash: environment.ntHash)
            framing.expectsCredSsp = true
            phase = .credSsp
        }
    }

    // MARK: - Network level authentication

    static func netBiosName(_ name: String) -> String {
        let base = name.split(separator: ".").first.map(String.init) ?? name
        return String(base.uppercased().filter { $0.isLetter || $0.isNumber || $0 == "-" }.prefix(15))
    }

    private func handleCredSsp(_ bytes: [UInt8]) {
        guard phase == .credSsp, var server = credSsp else { return fail("unexpected CredSSP message") }
        if throttle.isLockedOut(remoteAddress) {
            return fail("too many failed logins")
        }
        let step = server.receive(bytes)
        credSsp = server
        switch step {
        case .respond(let response):
            send(response)
        case .failed(let reason, let response):
            Self.logger.notice("network level authentication of \(server.authenticatedUserName, privacy: .public) from \(self.remoteAddress, privacy: .public) failed: \(reason, privacy: .public)")
            throttle.recordFailure(remoteAddress)
            if let response { send(response) }
            environment.observer?.connectionDidFail(remoteAddress: remoteAddress, reason: "authentication failed")
            close()
        case .completed(let credentials):
            // The client continues with RDP right away; queue its frames until the credentials are verified.
            framing.expectsCredSsp = false
            verifyNetworkCredentials(credentials)
        }
    }

    /// The NTLM exchange proved the password; it is checked once more with the configured login type.
    private func verifyNetworkCredentials(_ credentials: TsCredentials) {
        guard let context else { return }
        let environment = environment
        let bound = NIOLoopBound(self, eventLoop: context.eventLoop)
        let eventLoop = context.eventLoop
        let clientCredentials = ClientCredentials(userName: credentials.userName, domain: credentials.domain, password: credentials.password)
        Task {
            let isValid = await environment.credentialValidator.validate(clientCredentials)
            eventLoop.execute { bound.value.networkCredentialsVerified(userName: credentials.userName, isValid: isValid) }
        }
    }

    private func networkCredentialsVerified(userName: String, isValid: Bool) {
        guard phase == .credSsp else { return }
        guard isValid else {
            throttle.recordFailure(remoteAddress)
            environment.observer?.connectionDidFail(remoteAddress: remoteAddress, reason: "authentication failed")
            return fail("network credentials rejected by the login type")
        }
        throttle.recordSuccess(remoteAddress)
        networkAuthenticatedUser = userName
        credSsp = nil
        framing.expectsCredSsp = false
        if selectedProtocol == .credSspWithEarlyUserAuthorization {
            send([0, 0, 0, 0])
        }
        phase = .awaitingConnectInitial
        Self.logger.notice("\(userName, privacy: .public) from \(self.remoteAddress, privacy: .public) passed network level authentication")
        let queued = framesAwaitingAuthentication
        framesAwaitingAuthentication = []
        for frame in queued where phase != .closed {
            process(frame)
        }
    }

    private func handleConnectInitial(_ initial: McsConnectInitial) throws {
        let data = try ClientConnectionData.parse(GccConferenceCreateRequest.parse(initial.userData))
        clientData = data
        staticChannelIds = data.network.channels.indices.map { McsChannel.firstStaticChannelId + UInt16($0) }
        if let index = data.network.channels.firstIndex(where: { $0.name.lowercased() == GraphicsChannelController.staticChannelName }) {
            drdynvcChannelId = staticChannelIds[index]
        }
        if let index = data.network.channels.firstIndex(where: { $0.name.lowercased() == AudioChannelController.staticChannelName }) {
            rdpsndChannelId = staticChannelIds[index]
        }
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
            if channelId == McsChannel.ioChannelId {
                try handleIoChannelData(data)
            } else if channelId == drdynvcChannelId, phase == .active {
                try handleGraphicsChannelEvents(graphicsChannel.receive(chunk: data))
            } else if channelId == rdpsndChannelId, phase == .active {
                try handleAudioChannelEvents(audioChannel.receive(chunk: data, now: audioMilliseconds()))
            }
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
        let throttle = throttle
        let address = remoteAddress
        // With "always show the logon screen", credentials saved in the client are not used at all.
        let usesClientCredentials = !configuration.alwaysShowsLogonScreen
        let networkAuthenticated = networkAuthenticatedUser != nil
        if let networkAuthenticatedUser { clientInfo?.userName = networkAuthenticatedUser }
        Task {
            let isLockedOut = throttle.isLockedOut(address)
            let isValid = networkAuthenticated ? true : isLockedOut || !usesClientCredentials ? false : await environment.credentialValidator.validate(credentials)
            // An empty password means the client wants the logon screen; it is not a failed attempt.
            if !networkAuthenticated, !isLockedOut, usesClientCredentials, isValid || !credentials.password.isEmpty {
                if isValid { throttle.recordSuccess(address) } else { throttle.recordFailure(address) }
            }
            let result: SessionResourcesOutcome
            if !isValid, let desktopSize = environment.desktopSize {
                result = .deferred(desktopSize() ?? DesktopSize(width: 1920, height: 1080))
            } else {
                do {
                    result = .ready(try await environment.makeSessionResources())
                } catch {
                    result = .failed(error)
                }
            }
            eventLoop.execute {
                bound.value.authenticationFinished(isValid: isValid, isLockedOut: isLockedOut, resources: result)
            }
        }
    }

    private func authenticationFinished(isValid: Bool, isLockedOut: Bool, resources result: SessionResourcesOutcome) {
        guard phase == .authenticating else {
            if case .ready(let resources) = result { Task { await resources.frameSource.stop() } }
            return
        }
        sendMcs(.sendDataIndication(userId: userId, channelId: McsChannel.ioChannelId, data: LicenseErrorMessage.validClient()))
        guard !isLockedOut else {
            if case .ready(let resources) = result { Task { await resources.frameSource.stop() } }
            disconnect(errorInfo: SetErrorInfoPdu.serverDeniedConnection, reason: "too many failed logins")
            return
        }
        isAuthenticated = isValid
        if isValid {
            let method = networkAuthenticatedUser != nil ? "network level authentication" : "credentials sent by the client"
            Self.logger.notice("\(self.clientInfo?.userName ?? "", privacy: .public) from \(self.remoteAddress, privacy: .public) signed in with \(method, privacy: .public)")
        }
        switch result {
        case .ready(let resources):
            self.resources = resources
            desktopSize = resources.frameSource.desktopSize
            if !isValid { showLogonScreen() }
        case .deferred(let size):
            desktopSize = size
            showLogonScreen()
        case .failed(let error):
            Self.logger.error("cannot share the screen with \(self.remoteAddress, privacy: .public): \(String(describing: error), privacy: .public)")
            environment.observer?.connectionDidFail(remoteAddress: remoteAddress, reason: "cannot share the screen: \(error)")
            desktopSize = clientDesktopSize()
            logonForm = .messageOnly("iRdp cannot share the screen: \(error). Grant the permission on the Mac and connect again.")
        }
        keyTranslator = KeyboardTextTranslator(keyboardLayout: clientData?.core.keyboardLayout ?? 0)
        bitsPerPixel = negotiateBitsPerPixel()
        let capabilities = ServerCapabilities.make(desktopWidth: UInt16(desktopSize.width), desktopHeight: UInt16(desktopSize.height), bitsPerPixel: UInt16(bitsPerPixel))
        sendShareControl(.demandActive, body: DemandActivePdu(shareId: Self.shareId, capabilities: capabilities).encode())
        phase = .awaitingConfirmActive
    }

    private func showLogonScreen() {
        let userName = clientInfo?.userName ?? ""
        let password = clientInfo?.password ?? ""
        Self.logger.notice("credentials of \(userName, privacy: .public) from \(self.remoteAddress, privacy: .public) not accepted, showing logon screen")
        let suggested = environment.logonAppearance().defaultUserName ?? ""
        let showsError = !password.isEmpty && !configuration.alwaysShowsLogonScreen
        logonForm = LogonForm(userName: userName.isEmpty ? suggested : userName, message: showsError ? "The user name or password is incorrect." : nil)
    }

    private func clientDesktopSize() -> DesktopSize {
        let width = Int(clientData?.core.desktopWidth ?? 1024)
        let height = Int(clientData?.core.desktopHeight ?? 768)
        return DesktopSize(width: min(max(width, 640), 4096) & ~3, height: min(max(height, 480), 4096) & ~1)
    }

    private func negotiateBitsPerPixel() -> Int {
        let preferred = quality.current.bitsPerPixel
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
        // TS_ORDER_CAPABILITYSET body: orderFlags at 30, orderSupport at 32.
        let orders = confirm.capability(CapabilitySetType.order)?.body ?? []
        clientSupportsScreenCopy = orders.count >= 64 && orders[30] & 2 != 0 && orders[34] != 0
        if let bitmap = confirm.capability(CapabilitySetType.bitmap).flatMap({ try? BitmapCapability.parse($0.body) }),
           [16, 24, 32].contains(Int(bitmap.preferredBitsPerPixel)) {
            bitsPerPixel = Int(bitmap.preferredBitsPerPixel)
        }
        if let channelCapability = confirm.capability(CapabilitySetType.virtualChannel), channelCapability.body.count >= 8 {
            var reader = ByteReader(channelCapability.body)
            _ = try? reader.readUInt32LE()
            if let size = try? reader.readUInt32LE(), size >= 1600 { virtualChannelChunkLength = Int(size) }
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
        guard phase == .active else { return }
        // Until the user is authenticated, input only ever reaches the logon screen.
        guard isAuthenticated, logonForm == nil else {
            if logonForm != nil {
                Self.logger.debug("logon screen received \(events.count) input events")
                events.forEach { handleLogonInput($0) }
            }
            return
        }
        guard let sink = authenticatedInputSink else { return }
        events.forEach { sink.handle($0) }
    }

    // MARK: - Logon screen

    private func renderLogonScreen() {
        guard let logonForm, let pump else { return }
        if logonRenderer == nil || logonRenderer?.size != desktopSize {
            logonRenderer = LogonScreenRenderer(size: desktopSize, appearance: environment.logonAppearance())
        }
        guard let logonRenderer else { return }
        pump.submit(logonRenderer.render(logonForm))
    }

    private func handleLogonInput(_ event: RdpInputEvent) {
        guard var form = logonForm, let key = keyTranslator.translate(event) else { return }
        let action = form.handle(key)
        logonForm = form
        switch action {
        case .none:
            return
        case .changed:
            renderLogonScreen()
        case .submit(let userName, let password):
            renderLogonScreen()
            verifyLogon(userName: userName, password: password)
        }
    }

    private func verifyLogon(userName: String, password: String) {
        guard let context else { return }
        let environment = environment
        let throttle = throttle
        let address = remoteAddress
        let bound = NIOLoopBound(self, eventLoop: context.eventLoop)
        let eventLoop = context.eventLoop
        Task {
            let isLockedOut = throttle.isLockedOut(address)
            let isValid = isLockedOut ? false : await environment.credentialValidator.validate(ClientCredentials(userName: userName, password: password))
            if !isLockedOut {
                if isValid { throttle.recordSuccess(address) } else { throttle.recordFailure(address) }
            }
            let lockedNow = throttle.isLockedOut(address)
            eventLoop.execute { bound.value.logonVerified(userName: userName, isValid: isValid, isLockedOut: lockedNow) }
        }
    }

    private func logonVerified(userName: String, isValid: Bool, isLockedOut: Bool) {
        guard phase == .active, logonForm != nil else { return }
        if isValid {
            isAuthenticated = true
            clientInfo?.userName = userName
            if resources != nil {
                finishLogon()
            } else {
                prepareResourcesAfterLogon()
            }
            return
        }
        Self.logger.notice("logon screen: credentials of \(userName, privacy: .public) from \(self.remoteAddress, privacy: .public) rejected")
        if isLockedOut {
            logonForm = .messageOnly("Too many failed attempts. Try again in a few minutes.")
            renderLogonScreen()
            environment.observer?.connectionDidFail(remoteAddress: remoteAddress, reason: "too many failed logins")
            if let context {
                let bound = NIOLoopBound(self, eventLoop: context.eventLoop)
                context.eventLoop.scheduleTask(in: .seconds(3)) {
                    bound.value.disconnect(errorInfo: SetErrorInfoPdu.serverDeniedConnection, reason: "too many failed logins")
                }
            }
            return
        }
        logonForm?.rejected(message: "The user name or password is incorrect.")
        renderLogonScreen()
    }

    private func finishLogon() {
        logonForm = nil
        logonRenderer = nil
        startDesktop()
    }

    /// Creates screen capture and input only now that the user is authenticated.
    private func prepareResourcesAfterLogon() {
        guard let context else { return }
        let environment = environment
        let bound = NIOLoopBound(self, eventLoop: context.eventLoop)
        let eventLoop = context.eventLoop
        Task {
            let outcome: SessionResourcesOutcome
            do {
                outcome = .ready(try await environment.makeSessionResources())
            } catch {
                outcome = .failed(error)
            }
            eventLoop.execute { bound.value.resourcesPreparedAfterLogon(outcome) }
        }
    }

    private func resourcesPreparedAfterLogon(_ outcome: SessionResourcesOutcome) {
        guard phase == .active, isAuthenticated else {
            if case .ready(let resources) = outcome { Task { await resources.frameSource.stop() } }
            return
        }
        switch outcome {
        case .ready(let resources):
            if resources.frameSource.desktopSize != desktopSize {
                Self.logger.warning("desktop size changed during logon: \(resources.frameSource.desktopSize.width)x\(resources.frameSource.desktopSize.height)")
            }
            self.resources = resources
            finishLogon()
        case .failed(let error):
            environment.observer?.connectionDidFail(remoteAddress: remoteAddress, reason: "cannot share the screen: \(error)")
            logonForm = .messageOnly("iRdp cannot share the screen: \(error). Grant the permission on the Mac and connect again.")
            renderLogonScreen()
        case .deferred:
            break
        }
    }

    // MARK: - Active session

    private func activate() {
        guard let context, resources != nil || logonForm != nil else { return }
        // Before login only the logon screen exists; real frames come from the capture started in startDesktop().
        phase = .active
        send(FastPathUpdate.pdu([FastPathUpdate(code: .defaultPointer)]))
        let channel = context.channel
        let pump = FrameUpdatePump(encoder: ScreenUpdateEncoder(bitsPerPixel: bitsPerPixel, includesCompressionHeader: !clientSupportsCompressionWithoutHeader, supportsScreenCopy: clientSupportsScreenCopy)) { pdus, completion in
            channel.eventLoop.execute {
                var buffer = channel.allocator.buffer(capacity: pdus.reduce(0) { $0 + $1.count })
                for pdu in pdus { buffer.writeBytes(pdu) }
                channel.writeAndFlush(buffer).whenComplete { _ in completion() }
            }
        }
        self.pump = pump
        startGraphicsPipelineIfSupported()
        if logonForm != nil {
            renderLogonScreen()
        } else {
            startDesktop()
        }
    }

    /// Registers the session and starts sharing the screen.
    private func startDesktop() {
        guard isAuthenticated, logonForm == nil, let context, let resources, let pump else { return }
        authenticatedInputSink = resources.inputSink
        let bound = NIOLoopBound(self, eventLoop: context.eventLoop)
        let eventLoop = context.eventLoop
        let handle = RdpSessionHandle(
            disconnect: { eventLoop.execute { bound.value.disconnect(errorInfo: SetErrorInfoPdu.disconnectedByOtherConnection, reason: "replaced by a new session") } },
            applyQuality: { newQuality in eventLoop.execute { bound.value.applyQuality(newQuality) } }
        )
        let replaced = registry.register(sessionId, maximumSessions: configuration.maximumSessions, handle: handle)
        isRegistered = true
        replaced.forEach { $0.disconnect() }
        let info = RdpSessionInfo(id: sessionId, remoteAddress: remoteAddress, clientName: clientData?.core.clientName ?? "", userName: clientInfo?.userName ?? "", desktopSize: desktopSize, bitsPerPixel: bitsPerPixel, startedAt: Date())
        environment.observer?.sessionDidStart(info)
        Self.logger.info("session started for \(info.userName, privacy: .public) at \(info.desktopSize.width)x\(info.desktopSize.height)@\(info.bitsPerPixel)bpp")
        startAudioIfSupported()
        let frameSource = resources.frameSource
        let framesPerSecond = quality.current.framesPerSecond
        Task {
            do {
                try await frameSource.start { frame in pump.submit(frame) }
                await frameSource.setFrameRate(framesPerSecond)
            } catch {
                eventLoop.execute { bound.value.disconnect(errorInfo: SetErrorInfoPdu.serverDeniedConnection, reason: "screen capture failed: \(error)") }
            }
        }
    }

    /// Applies a quality change to the running session (encoder bit rate, sharpening and capture frame rate).
    private func applyQuality(_ newQuality: StreamingQuality) {
        pump?.updateQuality(newQuality)
        if let frameSource = resources?.frameSource {
            Task { await frameSource.setFrameRate(newQuality.framesPerSecond) }
        }
    }

    // MARK: - Graphics pipeline

    private func startGraphicsPipelineIfSupported() {
        let earlyFlags = clientData?.core.earlyCapabilityFlags ?? 0
        guard configuration.usesGraphicsPipeline, drdynvcChannelId != nil, earlyFlags & ClientCoreData.supportsGraphicsPipeline != 0 else {
            Self.logger.notice("using bitmap output: graphics enabled=\(self.configuration.usesGraphicsPipeline), drdynvc=\(self.drdynvcChannelId != nil), client flags=\(earlyFlags)")
            return
        }
        do {
            try handleGraphicsChannelEvents(graphicsChannel.start())
        } catch {
            Self.logger.error("graphics channel: \(String(describing: error), privacy: .public)")
        }
    }

    private func handleGraphicsChannelEvents(_ events: [GraphicsChannelEvent]) throws {
        for event in events {
            switch event {
            case .sendDynamicChannelPdu(let pdu):
                sendStaticChannelMessage(pdu)
            case .clientCapabilities(let sets):
                enableGraphicsPipeline(clientCapabilities: sets)
            case .frameAcknowledged(let queueDepth):
                pump?.frameAcknowledged(suspended: queueDepth == GraphicsClientPdu.suspendFrameAcknowledgement)
            case .cacheImportOffer:
                GraphicsChannelController.dynamicChannelPdus(forGraphicsMessage: GraphicsServerPdu.cacheImportReply()).forEach { sendStaticChannelMessage($0) }
            case .closed:
                pump?.replaceEncoder(ScreenUpdateEncoder(bitsPerPixel: bitsPerPixel, includesCompressionHeader: !clientSupportsCompressionWithoutHeader, supportsScreenCopy: clientSupportsScreenCopy))
                Self.logger.notice("graphics channel closed, resuming bitmap updates")
            }
        }
    }

    private func enableGraphicsPipeline(clientCapabilities sets: [GraphicsCapabilitySet]) {
        guard let chosen = GraphicsCapabilitySet.choose(from: sets), let pump, let channelId = drdynvcChannelId else { return }
        let codec: GraphicsPipelineCodec = configuration.usesVideoEncoding && chosen.supportsAvc420 ? .avc420 : .planar
        let packetize = Self.graphicsPacketizer(userId: userId, channelId: channelId, chunkLength: virtualChannelChunkLength)
        let encoder = GraphicsFrameEncoder(desktopSize: desktopSize, codec: codec, quality: quality.current, wrap: packetize)
        for packet in packetize(encoder.setupMessage(confirming: chosen)) { send(packet) }
        pump.replaceEncoder(encoder)
        Self.logger.info("graphics pipeline 0x\(String(chosen.version, radix: 16), privacy: .public) with \(codec == .avc420 ? "H.264 (AVC420)" : "planar", privacy: .public)")
    }

    /// Turns an RDPGFX message into wire packets: segmented data, DVC PDUs, static channel chunks, MCS, X.224 and TPKT.
    static func graphicsPacketizer(userId: UInt16, channelId: UInt16, chunkLength: Int) -> ([UInt8]) -> [[UInt8]] {
        { message in
            GraphicsChannelController.dynamicChannelPdus(forGraphicsMessage: message).flatMap { pdu in
                StaticChannelPdu.chunks(for: pdu, chunkLength: chunkLength).map { chunk in
                    X224DataTpdu.packet(McsDomainPdu.sendDataIndication(userId: userId, channelId: channelId, data: chunk).encode())
                }
            }
        }
    }

    private func sendStaticChannelMessage(_ message: [UInt8]) {
        guard let channelId = drdynvcChannelId else { return }
        for chunk in StaticChannelPdu.chunks(for: message, chunkLength: virtualChannelChunkLength) {
            sendMcs(.sendDataIndication(userId: userId, channelId: channelId, data: chunk))
        }
    }

    // MARK: - Audio output

    /// Offers the server's sound to the client; only once the user is signed in to the desktop.
    private func startAudioIfSupported() {
        guard resources?.audioSource != nil, rdpsndChannelId != nil, audioChannel.state == .idle else { return }
        do {
            try handleAudioChannelEvents(audioChannel.start())
        } catch {
            Self.logger.error("audio channel: \(String(describing: error), privacy: .public)")
        }
    }

    private func handleAudioChannelEvents(_ events: [AudioChannelController.Event]) throws {
        for event in events {
            switch event {
            case .send(let message):
                sendAudioChannelMessage(message)
            case .startStreaming(let format):
                startAudioCapture(format)
            case .stopStreaming:
                stopAudioCapture()
            }
        }
        if audioChannel.state == .unavailable, !isAudioStreaming {
            Self.logger.notice("client \(self.remoteAddress, privacy: .public) does not play any offered audio format")
        }
    }

    private func startAudioCapture(_ format: AudioStreamFormat) {
        guard let context, let audioSource = resources?.audioSource, !isAudioStreaming else { return }
        isAudioStreaming = true
        let bound = NIOLoopBound(self, eventLoop: context.eventLoop)
        let eventLoop = context.eventLoop
        Self.logger.info("audio output \(format.sampleRate) Hz, \(format.channels) channels")
        Task {
            do {
                try await audioSource.start(format: format) { samples in
                    eventLoop.execute { bound.value.sendAudio(samples) }
                }
            } catch {
                Self.logger.error("audio capture failed: \(String(describing: error), privacy: .public)")
            }
        }
    }

    private func stopAudioCapture() {
        guard isAudioStreaming, let audioSource = resources?.audioSource else { return }
        isAudioStreaming = false
        Task { await audioSource.stop() }
    }

    private func sendAudio(_ samples: [UInt8]) {
        guard phase == .active, isAudioStreaming else { return }
        for message in audioChannel.messages(forSamples: samples, now: audioMilliseconds()) {
            sendAudioChannelMessage(message)
        }
    }

    private func sendAudioChannelMessage(_ message: [UInt8]) {
        guard let channelId = rdpsndChannelId else { return }
        for chunk in StaticChannelPdu.chunks(for: message, chunkLength: virtualChannelChunkLength) {
            sendMcs(.sendDataIndication(userId: userId, channelId: channelId, data: chunk))
        }
    }

    private func audioMilliseconds() -> UInt64 {
        let elapsed = audioClockStart.duration(to: audioClock.now).components
        return UInt64(elapsed.seconds) * 1000 + UInt64(elapsed.attoseconds / 1_000_000_000_000_000)
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
        let wasActive = isRegistered
        phase = .closed
        pump?.stop()
        pump = nil
        authenticatedInputSink?.releaseAll()
        authenticatedInputSink = nil
        isAuthenticated = false
        if let resources {
            let frameSource = resources.frameSource
            let audioSource = isAudioStreaming ? resources.audioSource : nil
            isAudioStreaming = false
            Task {
                await frameSource.stop()
                await audioSource?.stop()
            }
            self.resources = nil
        }
        if isRegistered {
            registry.unregister(sessionId)
            isRegistered = false
        }
        if wasActive { environment.observer?.sessionDidEnd(sessionId) }
    }
}
