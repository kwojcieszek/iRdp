/// Builds RDPGFX server PDUs (header: cmdId, flags, pduLength).
public enum GraphicsServerPdu {
    static func pdu(_ command: GraphicsCommand, body: [UInt8]) -> [UInt8] {
        var writer = ByteWriter(capacity: body.count + 8)
        writer.writeUInt16LE(command.rawValue)
        writer.writeUInt16LE(0)
        writer.writeUInt32LE(UInt32(body.count + 8))
        writer.writeBytes(body)
        return writer.bytes
    }

    public static func capsConfirm(_ set: GraphicsCapabilitySet) -> [UInt8] {
        pdu(.capsConfirm, body: set.encode())
    }

    /// RDPGFX_RESET_GRAPHICS_PDU, which is always 340 bytes long.
    public static func resetGraphics(width: Int, height: Int) -> [UInt8] {
        var writer = ByteWriter(capacity: 332)
        writer.writeUInt32LE(UInt32(width))
        writer.writeUInt32LE(UInt32(height))
        writer.writeUInt32LE(1)
        writer.writeUInt32LE(0)
        writer.writeUInt32LE(0)
        writer.writeUInt32LE(UInt32(width - 1))
        writer.writeUInt32LE(UInt32(height - 1))
        writer.writeUInt32LE(1)
        writer.writeZeros(332 - writer.count)
        return pdu(.resetGraphics, body: writer.bytes)
    }

    public static func createSurface(id: UInt16, width: Int, height: Int) -> [UInt8] {
        var writer = ByteWriter()
        writer.writeUInt16LE(id)
        writer.writeUInt16LE(UInt16(width))
        writer.writeUInt16LE(UInt16(height))
        writer.writeUInt8(GraphicsCodec.pixelFormatXRGB)
        return pdu(.createSurface, body: writer.bytes)
    }

    public static func mapSurfaceToOutput(id: UInt16, x: Int = 0, y: Int = 0) -> [UInt8] {
        var writer = ByteWriter()
        writer.writeUInt16LE(id)
        writer.writeUInt16LE(0)
        writer.writeUInt32LE(UInt32(x))
        writer.writeUInt32LE(UInt32(y))
        return pdu(.mapSurfaceToOutput, body: writer.bytes)
    }

    public static func startFrame(id: UInt32, timestamp: UInt32) -> [UInt8] {
        var writer = ByteWriter()
        writer.writeUInt32LE(timestamp)
        writer.writeUInt32LE(id)
        return pdu(.startFrame, body: writer.bytes)
    }

    public static func endFrame(id: UInt32) -> [UInt8] {
        var writer = ByteWriter()
        writer.writeUInt32LE(id)
        return pdu(.endFrame, body: writer.bytes)
    }

    public static func wireToSurface(surfaceId: UInt16, codec: UInt16, destination: GraphicsRectangle, bitmap: [UInt8]) -> [UInt8] {
        var writer = ByteWriter(capacity: bitmap.count + 17)
        writer.writeUInt16LE(surfaceId)
        writer.writeUInt16LE(codec)
        writer.writeUInt8(GraphicsCodec.pixelFormatXRGB)
        destination.encode(into: &writer)
        writer.writeUInt32LE(UInt32(bitmap.count))
        writer.writeBytes(bitmap)
        return pdu(.wireToSurface1, body: writer.bytes)
    }

    public static func cacheImportReply() -> [UInt8] {
        pdu(.cacheImportReply, body: [0, 0])
    }

    /// RFX_AVC420_BITMAP_STREAM: metablock with region rectangles and quality values, then the H.264 Annex B stream.
    public static func avc420Bitmap(regions: [GraphicsRectangle], quantizationParameter: UInt8 = 22, quality: UInt8 = 100, h264: [UInt8]) -> [UInt8] {
        var writer = ByteWriter(capacity: h264.count + 4 + regions.count * 10)
        writer.writeUInt32LE(UInt32(regions.count))
        regions.forEach { $0.encode(into: &writer) }
        for _ in regions {
            writer.writeUInt8(quantizationParameter & 0x3F)
            writer.writeUInt8(quality)
        }
        writer.writeBytes(h264)
        return writer.bytes
    }
}
