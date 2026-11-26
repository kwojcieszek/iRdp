import Foundation
import RdpProtocol
import Testing
@testable import RdpServer

/// Runs a session over the graphics pipeline with H.264, including frame acknowledgement flow control.
@Suite(.serialized, .timeLimit(.minutes(1)))
struct GraphicsPipelineEndToEndTests {
    private func makeServer(usesVideoEncoding: Bool = true) -> RdpServer {
        let environment = RdpSessionEnvironment(
            credentialValidator: FixedCredentialValidator(userName: "kamil", password: "secret"),
            makeSessionResources: { RdpSessionResources(frameSource: TestPatternFrameSource(desktopSize: DesktopSize(width: 320, height: 180), interval: .milliseconds(20)), inputSink: nil) }
        )
        return RdpServer(configuration: RdpServerConfiguration(host: "127.0.0.1", port: 0, certificate: TestCertificate.shared, usesVideoEncoding: usesVideoEncoding), environment: environment)
    }

    private func wireToSurfaceCodecs(_ message: [UInt8]) throws -> [UInt16] {
        var reader = ByteReader(message)
        var codecs: [UInt16] = []
        while reader.remaining >= 8 {
            let command = try reader.readUInt16LE()
            _ = try reader.readUInt16LE()
            let length = Int(try reader.readUInt32LE())
            var body = ByteReader(try reader.readBytes(length - 8))
            if command == GraphicsCommand.wireToSurface1.rawValue {
                _ = try body.readUInt16LE()
                codecs.append(try body.readUInt16LE())
            }
        }
        return codecs
    }

    @Test(arguments: [true, false])
    func streamsFramesAndWaitsForAcknowledgements(usesVideoEncoding: Bool) async throws {
        let server = makeServer(usesVideoEncoding: usesVideoEncoding)
        let port = try await server.start()
        defer { Task { await server.stop() } }

        let (client, confirm) = try await RdpTestClient.connect(port: port)
        guard case .selected(_, let flags) = confirm.outcome else { Issue.record("no TLS"); return }
        #expect(flags & X224ConnectionConfirm.dynamicVirtualChannelGraphicsSupported != 0)
        let session = try await client.connectSession(userName: "kamil", password: "secret", supportsGraphicsPipeline: true)
        _ = try await session.activate()

        let setup = try await session.openGraphicsPipeline(capabilities: [GraphicsCapabilitySet(version: GraphicsCapabilitySet.version107, flags: 0)])
        #expect(setup == [GraphicsCommand.capsConfirm, .resetGraphics, .createSurface, .mapSurfaceToOutput].map(\.rawValue))

        var frameIds: [UInt32] = []
        for index in 0..<2 {
            let message = try await session.nextGraphicsMessage()
            #expect(try RdpTestClient.commands(in: message).first == GraphicsCommand.startFrame.rawValue)
            let expectedCodec = usesVideoEncoding && index == 0 ? GraphicsCodec.avc420 : GraphicsCodec.planar
            let codecs = try wireToSurfaceCodecs(message)
            #expect(!codecs.isEmpty && codecs.allSatisfy { $0 == expectedCodec })
            var reader = ByteReader(message)
            try reader.skip(12)
            frameIds.append(try reader.readUInt32LE())
        }
        #expect(frameIds == [1, 2])

        // Two frames are unacknowledged: the server must wait.
        let waiting = Task { try await session.nextGraphicsMessage() }
        try await Task.sleep(for: .milliseconds(300))
        #expect(!waiting.isCancelled)
        try await session.sendFrameAcknowledge(frameId: 1)
        let third = try await waiting.value
        #expect(try RdpTestClient.commands(in: third).first == GraphicsCommand.startFrame.rawValue)
        await session.close()
    }
}
