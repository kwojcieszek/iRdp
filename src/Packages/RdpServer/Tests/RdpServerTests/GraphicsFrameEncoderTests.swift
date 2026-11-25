import RdpProtocol
import Testing
@testable import RdpServer

struct GraphicsFrameEncoderTests {
    private func makeEncoder(codec: GraphicsPipelineCodec) -> GraphicsFrameEncoder {
        GraphicsFrameEncoder(desktopSize: DesktopSize(width: 200, height: 100), codec: codec, bitRate: 2_000_000, framesPerSecond: 30) { [$0] }
    }

    private func commands(_ message: [UInt8]) throws -> [UInt16] {
        var reader = ByteReader(message)
        var result: [UInt16] = []
        while reader.remaining >= 8 {
            result.append(try reader.readUInt16LE())
            _ = try reader.readUInt16LE()
            try reader.skip(Int(try reader.readUInt32LE()) - 8)
        }
        return result
    }

    @Test func alignsSurfaceToMacroblocks() {
        #expect(makeEncoder(codec: .avc420).encodedSize == DesktopSize(width: 208, height: 112))
    }

    @Test(arguments: [GraphicsPipelineCodec.avc420, .planar])
    func wrapsFramesInStartAndEndFrame(codec: GraphicsPipelineCodec) throws {
        let encoder = makeEncoder(codec: codec)
        let frame = TestPatternFrameSource.makeFrame(size: DesktopSize(width: 200, height: 100), tick: 0)
        let messages = encoder.encode(frame, forceFullUpdate: true)
        #expect(messages.count == 1)
        let types = try commands(messages[0])
        #expect(types.first == GraphicsCommand.startFrame.rawValue)
        #expect(types.last == GraphicsCommand.endFrame.rawValue)
        #expect(types.dropFirst().dropLast().allSatisfy { $0 == GraphicsCommand.wireToSurface1.rawValue })
        #expect(encoder.lastFrameId == 1)
        if codec == .planar {
            #expect(encoder.encode(frame, forceFullUpdate: false).isEmpty, "unchanged tiles are skipped")
        }
    }

    @Test func setupMessageConfirmsCapabilitiesAndCreatesSurface() throws {
        let encoder = makeEncoder(codec: .avc420)
        let types = try commands(encoder.setupMessage(confirming: GraphicsCapabilitySet(version: GraphicsCapabilitySet.version107, flags: 0)))
        #expect(types == [GraphicsCommand.capsConfirm, .resetGraphics, .createSurface, .mapSurfaceToOutput].map(\.rawValue))
    }
}
