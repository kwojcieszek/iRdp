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

    @Test func wrongPasswordIsRejected() async throws {
        let observer = RecordingObserver()
        let server = makeServer(observer: observer)
        let port = try await server.start()
        defer { Task { await server.stop() } }

        let (client, _) = try await RdpTestClient.connect(port: port)
        let session = try await client.connectSession(userName: "kamil", password: "wrong")
        var errorInfo: UInt32?
        do {
            while errorInfo == nil {
                let data = try await session.nextIoData()
                if data.starts(with: [0x80, 0x00]) { continue }
                for pdu in try SharePdu.parseAll(data) where pdu.dataType == .setErrorInfo {
                    var reader = ByteReader(pdu.body)
                    errorInfo = try reader.readUInt32LE()
                }
            }
        } catch RdpTestClientError.connectionClosed {}
        #expect(errorInfo == SetErrorInfoPdu.serverDeniedConnection)
        await #expect(throws: RdpTestClientError.self) {
            while true { _ = try await session.nextFrame() }
        }
        #expect(observer.startedSessions.isEmpty)
        #expect(observer.failureReasons.contains("authentication failed"))
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
