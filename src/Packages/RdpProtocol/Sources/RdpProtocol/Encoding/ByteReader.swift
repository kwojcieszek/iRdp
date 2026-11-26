/// Reads primitive values from a byte array, throwing `RdpProtocolError.truncated` on short input.
public struct ByteReader: Sendable {
    public let bytes: [UInt8]
    public private(set) var offset: Int

    public init(_ bytes: [UInt8], offset: Int = 0) {
        self.bytes = bytes
        self.offset = offset
    }

    public var remaining: Int { bytes.count - offset }
    public var isAtEnd: Bool { remaining <= 0 }

    private func require(_ count: Int) throws {
        guard count >= 0, remaining >= count else {
            throw RdpProtocolError.truncated(needed: count, available: max(remaining, 0))
        }
    }

    public func peekUInt8() throws -> UInt8 {
        try require(1)
        return bytes[offset]
    }

    public mutating func readUInt8() throws -> UInt8 {
        try require(1)
        defer { offset += 1 }
        return bytes[offset]
    }

    public mutating func readUInt16LE() throws -> UInt16 {
        try require(2)
        defer { offset += 2 }
        return UInt16(bytes[offset]) | UInt16(bytes[offset + 1]) << 8
    }

    public mutating func readUInt16BE() throws -> UInt16 {
        try require(2)
        defer { offset += 2 }
        return UInt16(bytes[offset]) << 8 | UInt16(bytes[offset + 1])
    }

    public mutating func readInt16LE() throws -> Int16 {
        Int16(bitPattern: try readUInt16LE())
    }

    public mutating func readUInt32LE() throws -> UInt32 {
        try require(4)
        defer { offset += 4 }
        return UInt32(bytes[offset])
            | UInt32(bytes[offset + 1]) << 8
            | UInt32(bytes[offset + 2]) << 16
            | UInt32(bytes[offset + 3]) << 24
    }

    public mutating func readUInt32BE() throws -> UInt32 {
        try require(4)
        defer { offset += 4 }
        return UInt32(bytes[offset]) << 24
            | UInt32(bytes[offset + 1]) << 16
            | UInt32(bytes[offset + 2]) << 8
            | UInt32(bytes[offset + 3])
    }

    public mutating func readBytes(_ count: Int) throws -> [UInt8] {
        try require(count)
        defer { offset += count }
        return Array(bytes[offset..<offset + count])
    }

    public mutating func readRemainingBytes() -> [UInt8] {
        guard remaining > 0 else { return [] }
        defer { offset = bytes.count }
        return Array(bytes[offset...])
    }

    public mutating func skip(_ count: Int) throws {
        try require(count)
        offset += count
    }

    /// Reads a UTF-16LE string of `byteCount` bytes and cuts it at the first null character.
    public mutating func readUTF16LE(byteCount: Int) throws -> String {
        let raw = try readBytes(byteCount)
        var units: [UInt16] = []
        var index = 0
        while index + 1 < raw.count {
            let unit = UInt16(raw[index]) | UInt16(raw[index + 1]) << 8
            if unit == 0 { break }
            units.append(unit)
            index += 2
        }
        return String(decoding: units, as: UTF16.self)
    }

    /// Reads an ASCII string of `byteCount` bytes and cuts it at the first null character.
    public mutating func readASCII(byteCount: Int) throws -> String {
        let raw = try readBytes(byteCount)
        let trimmed = raw.prefix { $0 != 0 }
        return String(decoding: trimmed, as: UTF8.self)
    }
}
