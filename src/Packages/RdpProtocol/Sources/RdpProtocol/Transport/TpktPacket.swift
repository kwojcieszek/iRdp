/// TPKT framing (RFC 1006): version 3, reserved byte, 16-bit big endian total length.
public enum TpktPacket {
    public static let version: UInt8 = 3
    public static let headerLength = 4

    public static func wrap(_ payload: [UInt8]) -> [UInt8] {
        let total = payload.count + headerLength
        return [version, 0, UInt8(truncatingIfNeeded: total >> 8), UInt8(truncatingIfNeeded: total)] + payload
    }

    /// Returns the payload of a complete TPKT packet.
    public static func unwrap(_ packet: [UInt8]) throws -> [UInt8] {
        var reader = ByteReader(packet)
        guard try reader.readUInt8() == version else { throw RdpProtocolError.invalidValue("TPKT version") }
        try reader.skip(1)
        let length = Int(try reader.readUInt16BE())
        guard length == packet.count else { throw RdpProtocolError.invalidValue("TPKT length \(length) != \(packet.count)") }
        return reader.readRemainingBytes()
    }
}
