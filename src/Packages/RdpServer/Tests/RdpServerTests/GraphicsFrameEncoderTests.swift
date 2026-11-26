import RdpProtocol
import Testing
@testable import RdpServer

enum SegmentedDataLimit {
    static let single = 65535
}

struct GraphicsFrameEncoderTests {
    private func makeEncoder(codec: GraphicsPipelineCodec) -> GraphicsFrameEncoder {
        GraphicsFrameEncoder(desktopSize: DesktopSize(width: 200, height: 100), codec: codec, quality: StreamingQuality(videoBitRate: 2_000_000)) { [$0] }
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

    private func codecs(_ message: [UInt8]) throws -> [UInt16] {
        var reader = ByteReader(message)
        var result: [UInt16] = []
        while reader.remaining >= 8 {
            let command = try reader.readUInt16LE()
            _ = try reader.readUInt16LE()
            var body = ByteReader(try reader.readBytes(Int(try reader.readUInt32LE()) - 8))
            if command == GraphicsCommand.wireToSurface1.rawValue {
                _ = try body.readUInt16LE()
                result.append(try body.readUInt16LE())
            }
        }
        return result
    }

    @Test func splitsLargePlanarFrameAcrossMessages() throws {
        let encoder = GraphicsFrameEncoder(desktopSize: DesktopSize(width: 640, height: 384), codec: .planar, quality: StreamingQuality()) { [$0] }
        var pixels = [UInt8](repeating: 0, count: 640 * 384 * 4)
        for index in pixels.indices { pixels[index] = UInt8.random(in: 0...255) }
        let messages = encoder.encode(ScreenFrame(width: 640, height: 384, bytesPerRow: 2560, pixels: pixels), forceFullUpdate: true)
        #expect(messages.count > 1)
        #expect(encoder.framesInLastBatch == 1)
        let allCommands = try messages.flatMap(commands)
        #expect(allCommands.first == GraphicsCommand.startFrame.rawValue)
        #expect(allCommands.last == GraphicsCommand.endFrame.rawValue)
        #expect(allCommands.dropFirst().dropLast().allSatisfy { $0 == GraphicsCommand.wireToSurface1.rawValue })
        #expect(messages.allSatisfy { $0.count <= SegmentedDataLimit.single })
        #expect(try messages.reduce(0) { $0 + (try codecs($1)).count } == 60)
    }

    @Test func refinesStillImageWithVideoFrames() throws {
        let encoder = makeEncoder(codec: .avc420)
        let frame = TestPatternFrameSource.makeFrame(size: DesktopSize(width: 200, height: 100), tick: 0)
        _ = encoder.encode(frame, forceFullUpdate: true)
        var refinements = 0
        while let messages = encoder.refinement() {
            refinements += 1
            #expect(try codecs(messages[0]) == [GraphicsCodec.avc420])
        }
        #expect(refinements == GraphicsFrameEncoder.videoRefinementFrames)
        #expect(encoder.encode(frame, forceFullUpdate: false).isEmpty, "identical frames send nothing")
    }

    @Test func videoFramesCoverTheWholeDesktop() throws {
        let encoder = makeEncoder(codec: .avc420)
        let message = try #require(encoder.encode(TestPatternFrameSource.makeFrame(size: DesktopSize(width: 200, height: 100), tick: 0), forceFullUpdate: true).first)
        var reader = ByteReader(message)
        try reader.skip(16)
        #expect(try reader.readUInt16LE() == GraphicsCommand.wireToSurface1.rawValue)
        try reader.skip(6 + 5 + 8 + 4)
        #expect(try reader.readUInt32LE() == 1, "one region")
        #expect([try reader.readUInt16LE(), try reader.readUInt16LE(), try reader.readUInt16LE(), try reader.readUInt16LE()] == [0, 0, 200, 100])
    }

    @Test func avcRefreshesBottomRightPixelAt4K() throws {
        let size = DesktopSize(width: 3840, height: 2160)
        let encoder = GraphicsFrameEncoder(desktopSize: size, codec: .avc420, quality: StreamingQuality()) { [$0] }
        var pixels = [UInt8](repeating: 0, count: size.width * size.height * 4)
        func frame() -> ScreenFrame {
            ScreenFrame(width: size.width, height: size.height, bytesPerRow: size.width * 4, pixels: pixels)
        }
        let initial = try #require(encoder.encode(frame(), forceFullUpdate: false).first)
        #expect(try codecs(initial) == [GraphicsCodec.avc420])
        #expect(encoder.encode(frame(), forceFullUpdate: false).isEmpty)
        pixels[pixels.count - 4] = 255
        let update = try #require(encoder.encode(frame(), forceFullUpdate: false).first)
        #expect(try codecs(update) == [GraphicsCodec.planar])
        var reader = ByteReader(update)
        try reader.skip(16 + 8 + 5) // StartFrame, WireToSurface header, surface ID, codec and format.
        #expect([try reader.readUInt16LE(), try reader.readUInt16LE(), try reader.readUInt16LE(), try reader.readUInt16LE()] == [3839, 2159, 3840, 2160])
        #expect(try codecs(#require(encoder.encode(frame(), forceFullUpdate: true).first)) == [GraphicsCodec.avc420])
    }

    @Test func lowQualityRefinesOnce() {
        let encoder = GraphicsFrameEncoder(desktopSize: DesktopSize(width: 200, height: 100), codec: .avc420, quality: StreamingQuality(videoBitRate: 2_000_000, sharpensStillImages: false)) { [$0] }
        _ = encoder.encode(TestPatternFrameSource.makeFrame(size: DesktopSize(width: 200, height: 100), tick: 0), forceFullUpdate: true)
        #expect(encoder.refinement() != nil)
        #expect(encoder.refinement() == nil)
    }

    @Test func groupsTilesIntoRows() {
        let grid = TileGrid(size: DesktopSize(width: 200, height: 100))
        #expect(grid.columns == 4 && grid.rows == 2)
        let rects = grid.rectangles(covering: [0, 1, 3, 4])
        #expect(rects.map { [$0.left, $0.top, $0.right, $0.bottom] } == [[0, 0, 128, 64], [192, 0, 200, 64], [0, 64, 64, 100]])
    }

    @Test func setupMessageConfirmsCapabilitiesAndCreatesSurface() throws {
        let encoder = makeEncoder(codec: .avc420)
        let types = try commands(encoder.setupMessage(confirming: GraphicsCapabilitySet(version: GraphicsCapabilitySet.version107, flags: 0)))
        #expect(types == [GraphicsCommand.capsConfirm, .resetGraphics, .createSurface, .mapSurfaceToOutput].map(\.rawValue))
    }
}
