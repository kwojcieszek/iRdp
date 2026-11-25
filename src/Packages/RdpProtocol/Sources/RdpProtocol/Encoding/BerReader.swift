/// Decodes the subset of ASN.1 BER used by MCS connect PDUs.
public struct BerReader {
    public var reader: ByteReader

    public init(_ reader: ByteReader) {
        self.reader = reader
    }

    public mutating func readLength() throws -> Int {
        let first = try reader.readUInt8()
        guard first & 0x80 != 0 else { return Int(first) }
        let count = Int(first & 0x7F)
        guard count > 0, count <= 4 else { throw RdpProtocolError.invalidValue("BER length of \(count) bytes") }
        var value = 0
        for _ in 0..<count { value = value << 8 | Int(try reader.readUInt8()) }
        return value
    }

    public mutating func expectTag(_ tag: UInt8) throws {
        let found = try reader.readUInt8()
        guard found == tag else {
            throw RdpProtocolError.invalidValue("BER tag 0x\(String(found, radix: 16)) instead of 0x\(String(tag, radix: 16))")
        }
    }

    /// Reads an application tag header and returns the content length.
    public mutating func readApplicationTag(_ number: UInt8) throws -> Int {
        try expectTag(0x7F)
        try expectTag(number)
        return try readLength()
    }

    public mutating func readInteger() throws -> Int {
        try expectTag(BerTag.integer)
        let length = try readLength()
        guard length > 0, length <= 8 else { throw RdpProtocolError.invalidValue("BER integer of \(length) bytes") }
        var value = 0
        for _ in 0..<length { value = value << 8 | Int(try reader.readUInt8()) }
        return value
    }

    public mutating func readEnumerated() throws -> UInt8 {
        try expectTag(BerTag.enumerated)
        let length = try readLength()
        guard length == 1 else { throw RdpProtocolError.invalidValue("BER enumerated of \(length) bytes") }
        return try reader.readUInt8()
    }

    public mutating func readBoolean() throws -> Bool {
        try expectTag(BerTag.boolean)
        let length = try readLength()
        guard length == 1 else { throw RdpProtocolError.invalidValue("BER boolean of \(length) bytes") }
        return try reader.readUInt8() != 0
    }

    public mutating func readOctetString() throws -> [UInt8] {
        try expectTag(BerTag.octetString)
        return try reader.readBytes(try readLength())
    }

    /// Reads a SEQUENCE and returns its raw content.
    public mutating func readSequence() throws -> [UInt8] {
        try expectTag(BerTag.sequence)
        return try reader.readBytes(try readLength())
    }
}
