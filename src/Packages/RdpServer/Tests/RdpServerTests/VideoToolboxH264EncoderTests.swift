import Testing
@testable import RdpServer

struct VideoToolboxH264EncoderTests {
    private func nalTypes(_ stream: [UInt8]) -> [UInt8] {
        var types: [UInt8] = []
        var index = 0
        while index + 4 < stream.count {
            if stream[index] == 0, stream[index + 1] == 0, stream[index + 2] == 0, stream[index + 3] == 1 {
                types.append(stream[index + 4] & 0x1F)
                index += 4
            } else {
                index += 1
            }
        }
        return types
    }

    @Test func producesAnnexBKeyFrameWithParameterSets() throws {
        let encoder = try VideoToolboxH264Encoder(width: 320, height: 192, bitRate: 2_000_000, framesPerSecond: 30)
        let frame = TestPatternFrameSource.makeFrame(size: DesktopSize(width: 320, height: 180), tick: 0)
        let key = try encoder.encode(frame, forceKeyFrame: true)
        let types = nalTypes(key)
        #expect(types.prefix(2) == [7, 8], "SPS and PPS come first")
        #expect(types.contains(5), "contains an IDR slice")
        let next = try encoder.encode(TestPatternFrameSource.makeFrame(size: DesktopSize(width: 320, height: 180), tick: 1), forceKeyFrame: false)
        #expect(!nalTypes(next).contains(5))
        #expect(next.count < key.count)
    }
}
