import Foundation
import RdpProtocol
import Testing
@testable import RdpServer

/// Runs the real server on a local port and drives it with the test client through TLS.
@Suite(.serialized, .timeLimit(.minutes(1)))
struct RdpServerEndToEndTests {
    private let desktop = DesktopSize(width: 320, height: 192)

    private func makeServer(inputSink: RecordingInputSink? = nil, observer: RecordingObserver? = nil, maximumSessions: Int = 1) -> RdpServer {
        let desktop = desktop
        let environment = RdpSessionEnvironment(
            credentialValidator: FixedCredentialValidator(userName: "kamil", password: "secret"),
            makeSessionResources: { RdpSessionResources(frameSource: TestPatternFrameSource(desktopSize: desktop, interval: .milliseconds(50)), inputSink: inputSink) },
            observer: observer
        )
        return RdpServer(configuration: RdpServerConfiguration(host: "127.0.0.1", port: 0, certificate: TestCertificate.shared, maximumSessions: maximumSessions), environment: environment)
    }

    @Test func fullSessionDeliversScreenUpdatesAndReceivesInput() async throws {
        let sink = RecordingInputSink()
        let observer = RecordingObserver()
        let server = makeServer(inputSink: sink, observer: observer)
        let port = try await server.start()
        defer { Task { await server.stop() } }

        let (client, confirm) = try await RdpTestClient.connect(port: port)
        #expect(confirm.outcome == .selected(.tls, flags: X224ConnectionConfirm.extendedClientDataSupported))
        let session = try await client.connectSession(userName: "kamil", password: "secret")
        let bitmap = try await session.activate()
        #expect(bitmap.desktopWidth == 320 && bitmap.desktopHeight == 192)
        #expect(bitmap.preferredBitsPerPixel == 32)

        var codes: [FastPathUpdateCode] = []
        var covered = 0
        while covered < 320 * 192 {
            for update in try await session.nextFastPathUpdates() {
                codes.append(update.code)
                if update.code == .bitmap {
                    for rect in try BitmapUpdate.parse(update.data).rectangles {
                        #expect(rect.bitsPerPixel == 32)
                        covered += Int(rect.destRight - rect.destLeft + 1) * Int(rect.destBottom - rect.destTop + 1)
                    }
                }
            }
        }
        #expect(codes.first == .defaultPointer)
        #expect(covered >= 320 * 192)

        let events: [RdpInputEvent] = [.mouse(flags: [.move], x: 10, y: 20), .keyboard(scancode: 0x1E, isExtended: false, isRelease: false)]
        try await session.send(FastPathInputPdu.encode(events))
        for _ in 0..<50 where sink.events.count < 2 { try await Task.sleep(for: .milliseconds(20)) }
        #expect(sink.events == events)
        #expect(observer.startedSessions.first?.userName == "kamil")
        #expect(observer.startedSessions.first?.clientName == "TESTCLIENT")
        #expect(server.activeSessionCount == 1)

        await session.close()
        for _ in 0..<50 where observer.endedSessions.isEmpty { try await Task.sleep(for: .milliseconds(20)) }
        #expect(observer.endedSessions.count == 1)
        #expect(sink.releaseCount == 1)
        #expect(server.activeSessionCount == 0)
    }

    /// Scancode events typing `text` on a US keyboard.
    private func typing(_ text: String) -> [RdpInputEvent] {
        var events: [RdpInputEvent] = []
        for character in text {
            guard let (scancode, (plain, _)) = KeyboardTextTranslator.usLayout.first(where: { $0.value.0 == character || $0.value.1 == character }) else { continue }
            let shifted = plain != character
            if shifted { events.append(.keyboard(scancode: 0x2A, isExtended: false, isRelease: false)) }
            events.append(.keyboard(scancode: scancode, isExtended: false, isRelease: false))
            events.append(.keyboard(scancode: scancode, isExtended: false, isRelease: true))
            if shifted { events.append(.keyboard(scancode: 0x2A, isExtended: false, isRelease: true)) }
        }
        return events
    }

    private func pressing(_ scancode: UInt8) -> [RdpInputEvent] {
        [.keyboard(scancode: scancode, isExtended: false, isRelease: false), .keyboard(scancode: scancode, isExtended: false, isRelease: true)]
    }

    @Test(arguments: ["", "wrong"])
    func missingOrWrongCredentialsShowLogonScreenThatSignsIn(clientPassword: String) async throws {
        let sink = RecordingInputSink()
        let observer = RecordingObserver()
        let server = makeServer(inputSink: sink, observer: observer)
        let port = try await server.start()
        defer { Task { await server.stop() } }

        let session = try await RdpTestClient.connect(port: port).0.connectSession(userName: clientPassword.isEmpty ? "" : "kamil", password: clientPassword)
        let bitmap = try await session.activate()
        #expect(bitmap.desktopWidth == 320, "the logon screen uses the desktop size")
        let first = try await session.nextFastPathUpdates()
        #expect(!first.isEmpty)
        #expect(observer.startedSessions.isEmpty, "no session before signing in")

        // Wrong password on the logon screen keeps the logon screen.
        let wrong = clientPassword.isEmpty ? typing("kamil") + pressing(0x0F) + typing("nope") + pressing(0x1C) : typing("nope") + pressing(0x1C)
        try await session.send(FastPathInputPdu.encode(wrong))
        try await Task.sleep(for: .milliseconds(200))
        #expect(observer.startedSessions.isEmpty)
        #expect(sink.events.isEmpty, "logon input never reaches the Mac")

        try await session.send(FastPathInputPdu.encode(typing("secret") + pressing(0x1C)))
        for _ in 0..<100 where observer.startedSessions.isEmpty { try await Task.sleep(for: .milliseconds(20)) }
        #expect(observer.startedSessions.first?.userName == "kamil")

        try await session.send(FastPathInputPdu.encode([.mouse(flags: [.move], x: 1, y: 2)]))
        for _ in 0..<50 where sink.events.isEmpty { try await Task.sleep(for: .milliseconds(20)) }
        #expect(sink.events == [.mouse(flags: [.move], x: 1, y: 2)])
        await session.close()
    }

    @Test func screenSharingErrorIsShownToTheClient() async throws {
        struct PermissionMissing: Error {}
        let observer = RecordingObserver()
        let environment = RdpSessionEnvironment(
            credentialValidator: FixedCredentialValidator(userName: "kamil", password: "secret"),
            makeSessionResources: { throw PermissionMissing() },
            observer: observer
        )
        let server = RdpServer(configuration: RdpServerConfiguration(host: "127.0.0.1", port: 0, certificate: TestCertificate.shared), environment: environment)
        let port = try await server.start()
        defer { Task { await server.stop() } }
        let session = try await RdpTestClient.connect(port: port).0.connectSession(userName: "kamil", password: "secret")
        let bitmap = try await session.activate()
        #expect(bitmap.desktopWidth == 800 && bitmap.desktopHeight == 600, "falls back to the client size")
        #expect(!(try await session.nextFastPathUpdates()).isEmpty)
        #expect(observer.startedSessions.isEmpty)
        #expect(observer.failureReasons.contains { $0.contains("cannot share the screen") })
        await session.close()
    }

    @Test func clientWithoutTlsIsRefused() async throws {
        let server = makeServer()
        let port = try await server.start()
        defer { Task { await server.stop() } }
        let (client, confirm) = try await RdpTestClient.connect(port: port, requestedProtocols: .standardRdp)
        #expect(confirm.outcome == .failure(.sslRequiredByServer))
        await #expect(throws: RdpTestClientError.self) { _ = try await client.nextFrame() }
        await client.close()
    }

    @Test func secondSessionReplacesTheFirst() async throws {
        let server = makeServer(maximumSessions: 1)
        let port = try await server.start()
        defer { Task { await server.stop() } }

        let first = try await RdpTestClient.connect(port: port).0.connectSession(userName: "kamil", password: "secret")
        _ = try await first.activate()
        let second = try await RdpTestClient.connect(port: port).0.connectSession(userName: "kamil", password: "secret")
        _ = try await second.activate()

        var replacedError: UInt32?
        do {
            while replacedError == nil {
                for pdu in try SharePdu.parseAll(try await first.nextIoData()) where pdu.dataType == .setErrorInfo {
                    var reader = ByteReader(pdu.body)
                    replacedError = try reader.readUInt32LE()
                }
            }
        } catch RdpTestClientError.connectionClosed {}
        #expect(replacedError == SetErrorInfoPdu.disconnectedByOtherConnection)
        #expect(server.activeSessionCount == 1)
        await first.close()
        await second.close()
    }

    @Test func serverCanBeRestarted() async throws {
        let server = makeServer()
        let port = try await server.start()
        await server.stop()
        let secondPort = try await server.start()
        #expect(secondPort > 0 && port > 0)
        await server.stop()
    }
}
