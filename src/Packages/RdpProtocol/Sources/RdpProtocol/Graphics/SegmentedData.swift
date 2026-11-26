/// RDP_SEGMENTED_DATA framing of RDPGFX messages, sent without bulk compression (MS-RDPEGFX 2.2.5).
public enum SegmentedData {
    static let single: UInt8 = 0xE0
    static let multipart: UInt8 = 0xE1
    /// RDP8 bulk encoding header without the PACKET_COMPRESSED flag.
    static let uncompressedRdp8: UInt8 = 0x04
    static let compressedFlag: UInt8 = 0x20
    public static let maximumSegmentLength = 65535

    public static func wrap(_ message: [UInt8]) -> [UInt8] {
        if message.count <= maximumSegmentLength {
            return [single, uncompressedRdp8] + message
        }
        var writer = ByteWriter(capacity: message.count + 16)
        writer.writeUInt8(multipart)
        let segmentCount = (message.count + maximumSegmentLength - 1) / maximumSegmentLength
        writer.writeUInt16LE(UInt16(segmentCount))
        writer.writeUInt32LE(UInt32(message.count))
        var offset = 0
        while offset < message.count {
            let end = min(offset + maximumSegmentLength, message.count)
            writer.writeUInt32LE(UInt32(end - offset + 1))
            writer.writeUInt8(uncompressedRdp8)
            writer.writeBytes(message[offset..<end])
            offset = end
        }
        return writer.bytes
    }

    /// Unwraps uncompressed segmented data (clients send RDPGFX messages uncompressed).
    public static func unwrap(_ data: [UInt8]) throws -> [UInt8] {
        var reader = ByteReader(data)
        switch try reader.readUInt8() {
        case single:
            let header = try reader.readUInt8()
            guard header & compressedFlag == 0 else { throw RdpProtocolError.unsupported("compressed RDPGFX data") }
            return reader.readRemainingBytes()
        case multipart:
            let count = Int(try reader.readUInt16LE())
            _ = try reader.readUInt32LE()
            var result: [UInt8] = []
            for _ in 0..<count {
                let size = Int(try reader.readUInt32LE())
                let header = try reader.readUInt8()
                guard header & compressedFlag == 0 else { throw RdpProtocolError.unsupported("compressed RDPGFX data") }
                result += try reader.readBytes(size - 1)
            }
            return result
        default:
            throw RdpProtocolError.invalidValue("segmented data descriptor")
        }
    }
}
