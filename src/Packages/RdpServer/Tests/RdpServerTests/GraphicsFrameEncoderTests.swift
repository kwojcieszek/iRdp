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

    @Test func sharpensStillImageWithLosslessTiles() throws {
        let encoder = makeEncoder(codec: .avc420)
        let frame = TestPatternFrameSource.makeFrame(size: DesktopSize(width: 200, height: 100), tick: 0)
        _ = encoder.encode(frame, forceFullUpdate: true)
        #expect(encoder.lossyTiles.count == 8, "4 × 2 tiles drawn with H.264")
        let refinement = try #require(encoder.refinement())
        let used = try codecs(refinement[0])
        #expect(used.count == 8 && used.allSatisfy { $0 == GraphicsCodec.planar })
        #expect(encoder.refinement() == nil, "nothing left to sharpen")
    }

    @Test func splitsLargeRefinementsIntoSmallFrames() throws {
        let encoder = GraphicsFrameEncoder(desktopSize: DesktopSize(width: 640, height: 384), codec: .avc420, quality: StreamingQuality(videoBitRate: 2_000_000)) { [$0] }
        var pixels = [UInt8](repeating: 0, count: 640 * 384 * 4)
        for index in pixels.indices { pixels[index] = UInt8.random(in: 0...255) }
        _ = encoder.encode(ScreenFrame(width: 640, height: 384, bytesPerRow: 2560, pixels: pixels), forceFullUpdate: true)
        var steps = 0
        var tiles = 0
        while let messages = encoder.refinement() {
            steps += 1
            #expect(messages[0].count <= SegmentedDataLimit.single, "fits in one segment")
            tiles += try codecs(messages[0]).count
        }
        #expect(tiles == 60)
        #expect(steps > 1)
    }

    @Test func videoUpdatesOnlyChangedRegions() throws {
        let encoder = makeEncoder(codec: .avc420)
        let first = TestPatternFrameSource.makeFrame(size: DesktopSize(width: 200, height: 100), tick: 0)
        _ = encoder.encode(first, forceFullUpdate: true)
        _ = encoder.refinement()
        var pixels = first.pixels
        pixels[(10 * 200 + 150) * 4] ^= 0xFF
        let changed = ScreenFrame(width: 200, height: 100, bytesPerRow: 800, pixels: pixels)
        #expect(!encoder.encode(changed, forceFullUpdate: false).isEmpty)
        #expect(encoder.lossyTiles == [2], "only the changed tile is lossy")
        #expect(encoder.encode(changed, forceFullUpdate: false).isEmpty, "identical frames send nothing")
    }

    @Test func lowQualityRefinesWithVideoInsteadOfLosslessTiles() throws {
        let encoder = GraphicsFrameEncoder(desktopSize: DesktopSize(width: 200, height: 100), codec: .avc420, quality: StreamingQuality(videoBitRate: 2_000_000, sharpensStillImages: false)) { [$0] }
        _ = encoder.encode(TestPatternFrameSource.makeFrame(size: DesktopSize(width: 200, height: 100), tick: 0), forceFullUpdate: true)
        let first = try #require(encoder.refinement())
        #expect(try codecs(first[0]).allSatisfy { $0 == GraphicsCodec.avc420 })
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
