/// Helpers for the aligned PER encoding used by the GCC and MCS domain PDUs.
public enum PerEncoding {
    public static func length(_ value: Int) -> [UInt8] {
        if value < 0x80 { return [UInt8(value)] }
        return [UInt8(0x80 | ((value >> 8) & 0x7F)), UInt8(truncatingIfNeeded: value)]
    }

    public static func readLength(_ reader: inout ByteReader) throws -> Int {
        let first = try reader.readUInt8()
        guard first & 0x80 != 0 else { return Int(first) }
        let second = try reader.readUInt8()
        return Int(first & 0x7F) << 8 | Int(second)
    }
}
