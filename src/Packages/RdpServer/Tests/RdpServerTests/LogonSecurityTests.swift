import CoreGraphics
import ImageIO
import Foundation
import RdpProtocol
import Testing
@testable import RdpServer

/// Before a successful login nothing may reach the Mac: no input events and no screen capture.
@Suite(.serialized, .timeLimit(.minutes(1)))
struct LogonSecurityTests {
    private func pressing(_ scancode: UInt8, extended: Bool = false) -> [RdpInputEvent] {
        [.keyboard(scancode: scancode, isExtended: extended, isRelease: false), .keyboard(scancode: scancode, isExtended: extended, isRelease: true)]
    }

    /// Every kind of input event a client can send, without Enter (which would submit the form).
    private var everyKindOfInput: [RdpInputEvent] {
        [
            .mouse(flags: [.move], x: 10, y: 10),
            .mouse(flags: [.down, .button1], x: 10, y: 10),
            .mouse(flags: [.button1], x: 10, y: 10),
            .mouse(flags: [.down, .button2], x: 20, y: 20),
            .mouse(flags: [.wheel], x: 20, y: 20),
            .mouse(flags: [.horizontalWheel], x: 20, y: 20),
            .extendedMouse(flags: [.down, .xButton1], x: 5, y: 5),
            .relativeMouse(flags: [.move], deltaX: 5, deltaY: 5),
            .unicodeKeyboard(codeUnit: 0x61, isRelease: false),
            .synchronize([.numLock]),
        ] + pressing(0x5B, extended: true) + pressing(0x1D) + pressing(0x0F) + pressing(0x01)
    }

    @Test func nothingReachesTheMacBeforeLogin() async throws {
        let sink = RecordingInputSink()
        let observer = RecordingObserver()
        let source = CountingFrameSource(TestPatternFrameSource(desktopSize: DesktopSize(width: 320, height: 192)))
        let environment = RdpSessionEnvironment(
            credentialValidator: FixedCredentialValidator(userName: "kamil", password: "secret"),
            makeSessionResources: { RdpSessionResources(frameSource: source, inputSink: sink) },
            observer: observer
        )
        let server = RdpServer(configuration: RdpServerConfiguration(host: "127.0.0.1", port: 0, certificate: TestCertificate.shared), environment: environment)
        let port = try await server.start()
        defer { Task { await server.stop() } }

        let session = try await RdpTestClient.connect(port: port).0.connectSession(userName: "", password: "")
        _ = try await session.activate()
        try await session.send(FastPathInputPdu.encode(everyKindOfInput))
        // Slow-path input must be filtered the same way.
        var slowPath = ByteWriter()
        slowPath.writeUInt16LE(1)
        slowPath.writeUInt16LE(0)
        slowPath.writeUInt32LE(0)
        slowPath.writeUInt16LE(0x8001)
        slowPath.writeUInt16LE(PointerFlags.move.rawValue)
        slowPath.writeUInt16LE(30)
        slowPath.writeUInt16LE(30)
        try await session.sendData(.input, shareId: 0x0001_03EA, body: slowPath.bytes)
        try await Task.sleep(for: .milliseconds(300))

        #expect(sink.events.isEmpty, "no input reaches the Mac before login")
        #expect(source.startCount == 0, "the screen is not captured before login")
        #expect(observer.startedSessions.isEmpty)
        #expect(server.activeSessionCount == 0)

        // A wrong password keeps everything locked.
        try await session.send(FastPathInputPdu.encode(pressing(0x1C)))
        try await Task.sleep(for: .milliseconds(200))
        #expect(sink.events.isEmpty)
        #expect(source.startCount == 0)
        await session.close()
    }

    @Test func inputStopsWhenTheSessionEnds() async throws {
        let sink = RecordingInputSink()
        let source = CountingFrameSource(TestPatternFrameSource(desktopSize: DesktopSize(width: 320, height: 192)))
        let environment = RdpSessionEnvironment(
            credentialValidator: FixedCredentialValidator(userName: "kamil", password: "secret"),
            makeSessionResources: { RdpSessionResources(frameSource: source, inputSink: sink) }
        )
        let server = RdpServer(configuration: RdpServerConfiguration(host: "127.0.0.1", port: 0, certificate: TestCertificate.shared), environment: environment)
        let port = try await server.start()
        defer { Task { await server.stop() } }

        let session = try await RdpTestClient.connect(port: port).0.connectSession(userName: "kamil", password: "secret")
        _ = try await session.activate()
        try await session.send(FastPathInputPdu.encode([.mouse(flags: [.move], x: 1, y: 1)]))
        for _ in 0..<50 where sink.events.isEmpty { try await Task.sleep(for: .milliseconds(20)) }
        #expect(sink.events.count == 1)
        #expect(source.startCount == 1)
        await session.close()
        for _ in 0..<50 where sink.releaseCount == 0 { try await Task.sleep(for: .milliseconds(20)) }
        #expect(sink.releaseCount == 1, "held keys and buttons are released when the client disconnects")
    }
}

/// With "always show the logon screen" credentials saved in the client never open a session.
@Suite(.serialized, .timeLimit(.minutes(1)))
struct AlwaysShowLogonScreenTests {
    @Test func savedClientCredentialsAreIgnored() async throws {
        let sink = RecordingInputSink()
        let observer = RecordingObserver()
        let source = CountingFrameSource(TestPatternFrameSource(desktopSize: DesktopSize(width: 320, height: 192)))
        let environment = RdpSessionEnvironment(
            credentialValidator: FixedCredentialValidator(userName: "kamil", password: "secret"),
            makeSessionResources: { RdpSessionResources(frameSource: source, inputSink: sink) },
            observer: observer
        )
        let configuration = RdpServerConfiguration(host: "127.0.0.1", port: 0, certificate: TestCertificate.shared, alwaysShowsLogonScreen: true)
        let server = RdpServer(configuration: configuration, environment: environment)
        let port = try await server.start()
        defer { Task { await server.stop() } }

        // Correct saved credentials: still only the logon screen.
        let session = try await RdpTestClient.connect(port: port).0.connectSession(userName: "kamil", password: "secret")
        _ = try await session.activate()
        try await session.send(FastPathInputPdu.encode([.mouse(flags: [.move], x: 3, y: 3)]))
        try await Task.sleep(for: .milliseconds(300))
        #expect(observer.startedSessions.isEmpty)
        #expect(source.startCount == 0)
        #expect(sink.events.isEmpty)

        // Typing the password on the logon screen signs in (the user name is prefilled).
        var events: [RdpInputEvent] = []
        for scancode: UInt8 in [0x1F, 0x12, 0x2E, 0x13, 0x12, 0x14, 0x1C] {
            events += [.keyboard(scancode: scancode, isExtended: false, isRelease: false), .keyboard(scancode: scancode, isExtended: false, isRelease: true)]
        }
        try await session.send(FastPathInputPdu.encode(events))
        for _ in 0..<100 where observer.startedSessions.isEmpty { try await Task.sleep(for: .milliseconds(20)) }
        #expect(observer.startedSessions.first?.userName == "kamil")
        #expect(source.startCount == 1)
        await session.close()
    }
}

/// With a desktop size provider, nothing that can capture the screen is created before login.
@Suite(.serialized, .timeLimit(.minutes(1)))
struct DeferredResourcesTests {
    @Test func screenCaptureIsCreatedOnlyAfterLogin() async throws {
        let created = EventLog()
        let observer = RecordingObserver()
        let environment = RdpSessionEnvironment(
            credentialValidator: FixedCredentialValidator(userName: "kamil", password: "secret"),
            makeSessionResources: {
                created.append("resources")
                return RdpSessionResources(frameSource: TestPatternFrameSource(desktopSize: DesktopSize(width: 320, height: 192)), inputSink: RecordingInputSink())
            },
            observer: observer,
            desktopSize: { DesktopSize(width: 320, height: 192) }
        )
        let server = RdpServer(configuration: RdpServerConfiguration(host: "127.0.0.1", port: 0, certificate: TestCertificate.shared, alwaysShowsLogonScreen: true), environment: environment)
        let port = try await server.start()
        defer { Task { await server.stop() } }

        let session = try await RdpTestClient.connect(port: port).0.connectSession(userName: "kamil", password: "secret")
        let bitmap = try await session.activate()
        #expect(bitmap.desktopWidth == 320, "the logon screen uses the provided desktop size")
        #expect(!(try await session.nextFastPathUpdates()).isEmpty, "the logon screen is shown")
        #expect(created.entries.isEmpty, "no screen capture exists before login")

        var events: [RdpInputEvent] = []
        for scancode: UInt8 in [0x1F, 0x12, 0x2E, 0x13, 0x12, 0x14, 0x1C] {
            events += [.keyboard(scancode: scancode, isExtended: false, isRelease: false), .keyboard(scancode: scancode, isExtended: false, isRelease: true)]
        }
        try await session.send(FastPathInputPdu.encode(events))
        for _ in 0..<100 where observer.startedSessions.isEmpty { try await Task.sleep(for: .milliseconds(20)) }
        #expect(created.entries == ["resources"])
        #expect(observer.startedSessions.count == 1)
        await session.close()
    }
}

/// Writes PNG previews of the logon screen when IRDP_PREVIEW_DIR is set.
struct LogonScreenPreviewTests {
    @Test func rendersPreviews() throws {
        let renderer = LogonScreenRenderer(size: DesktopSize(width: 1920, height: 1080), appearance: LogonScreenAppearance(serverName: "Mac Studio"))
        var form = LogonForm(userName: "kamil")
        for character in "secret" { _ = form.handle(.character(character)) }
        let typing = renderer.render(form)
        form.rejected(message: "The user name or password is incorrect.")
        let rejected = renderer.render(form)
        #expect(typing.pixels != rejected.pixels)
        guard let directory = ProcessInfo.processInfo.environment["IRDP_PREVIEW_DIR"] else { return }
        for (name, frame) in [("logon-glass.png", typing), ("logon-glass-rejected.png", rejected)] {
            guard let provider = CGDataProvider(data: Data(frame.pixels) as CFData),
                  let image = CGImage(width: frame.width, height: frame.height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: frame.bytesPerRow, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue), provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent),
                  let destination = CGImageDestinationCreateWithURL(URL(fileURLWithPath: directory).appendingPathComponent(name) as CFURL, "public.png" as CFString, 1, nil) else { continue }
            CGImageDestinationAddImage(destination, image, nil)
            CGImageDestinationFinalize(destination)
        }
    }
}
