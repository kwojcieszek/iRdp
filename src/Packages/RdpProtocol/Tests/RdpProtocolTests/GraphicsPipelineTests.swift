import Testing
@testable import RdpProtocol

struct GraphicsPipelineTests {
    @Test func choosesNewestVersionWithAvc() {
        let sets = [
            GraphicsCapabilitySet(version: GraphicsCapabilitySet.version8, flags: 0),
            GraphicsCapabilitySet(version: GraphicsCapabilitySet.version81, flags: GraphicsCapabilitySet.flagAvc420Enabled),
            GraphicsCapabilitySet(version: GraphicsCapabilitySet.version107, flags: GraphicsCapabilitySet.flagAvcDisabled),
            GraphicsCapabilitySet(version: GraphicsCapabilitySet.version105, flags: 0),
        ]
        #expect(GraphicsCapabilitySet.choose(from: sets)?.version == GraphicsCapabilitySet.version105)
        let withoutAvc = [GraphicsCapabilitySet(version: GraphicsCapabilitySet.version8, flags: 0), GraphicsCapabilitySet(version: GraphicsCapabilitySet.version81, flags: 0)]
        let chosen = GraphicsCapabilitySet.choose(from: withoutAvc)
        #expect(chosen?.version == GraphicsCapabilitySet.version81)
        #expect(chosen?.supportsAvc420 == false)
        #expect(GraphicsCapabilitySet.choose(from: [GraphicsCapabilitySet(version: 0x0001_0000, flags: 0)]) == nil)
    }

    @Test func roundTripsClientPdus() throws {
        let caps = GraphicsClientPdu.capsAdvertise([GraphicsCapabilitySet(version: GraphicsCapabilitySet.version107, flags: 0)])
        let ack = GraphicsClientPdu.frameAcknowledge(queueDepth: 0, frameId: 5, totalFramesDecoded: 5)
        #expect(try GraphicsClientPdu.parseAll(caps.encode() + ack.encode()) == [caps, ack])
    }

    @Test func resetGraphicsIs340BytesLong() throws {
        let pdu = GraphicsServerPdu.resetGraphics(width: 1920, height: 1080)
        #expect(pdu.count == 340)
        var reader = ByteReader(pdu)
        #expect(try reader.readUInt16LE() == GraphicsCommand.resetGraphics.rawValue)
        _ = try? reader.readUInt16LE()
        #expect(try reader.readUInt32LE() == 340)
    }

    @Test func encodesAvc420Metablock() throws {
        let bitmap = GraphicsServerPdu.avc420Bitmap(regions: [GraphicsRectangle(left: 0, top: 0, right: 64, bottom: 32)], quantizationParameter: 22, quality: 100, h264: [0, 0, 0, 1, 0x67])
        #expect(bitmap == [1, 0, 0, 0, 0, 0, 0, 0, 64, 0, 32, 0, 22, 100, 0, 0, 0, 1, 0x67])
        let pdu = GraphicsServerPdu.wireToSurface(surfaceId: 0, codec: GraphicsCodec.avc420, destination: GraphicsRectangle(left: 0, top: 0, right: 64, bottom: 32), bitmap: bitmap)
        #expect(pdu.count == 8 + 17 + bitmap.count)
    }
}
