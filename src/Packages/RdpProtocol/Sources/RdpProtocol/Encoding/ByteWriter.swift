/// Appends primitive values to a growing byte array in little or big endian order.
public struct ByteWriter: Sendable {
    public private(set) var bytes: [UInt8]

    public init(capacity: Int = 64) {
        bytes = []
        bytes.reserveCapacity(capacity)
    }

    public var count: Int { bytes.count }

    public mutating func writeUInt8(_ value: UInt8) {
        bytes.append(value)
    }

    public mutating func writeUInt16LE(_ value: UInt16) {
        bytes.append(UInt8(truncatingIfNeeded: value))
        bytes.append(UInt8(truncatingIfNeeded: value >> 8))
    }

    public mutating func writeUInt16BE(_ value: UInt16) {
        bytes.append(UInt8(truncatingIfNeeded: value >> 8))
        bytes.append(UInt8(truncatingIfNeeded: value))
    }

    public mutating func writeInt16LE(_ value: Int16) {
        writeUInt16LE(UInt16(bitPattern: value))
    }

    public mutating func writeUInt32LE(_ value: UInt32) {
        for shift in stride(from: 0, to: 32, by: 8) {
            bytes.append(UInt8(truncatingIfNeeded: value >> UInt32(shift)))
        }
    }

    public mutating func writeUInt32BE(_ value: UInt32) {
        for shift in stride(from: 24, through: 0, by: -8) {
            bytes.append(UInt8(truncatingIfNeeded: value >> UInt32(shift)))
        }
    }

    public mutating func writeBytes<S: Sequence>(_ sequence: S) where S.Element == UInt8 {
        bytes.append(contentsOf: sequence)
    }

    public mutating func writeZeros(_ count: Int) {
        bytes.append(contentsOf: repeatElement(0, count: count))
    }

    /// Writes a UTF-16LE string. When `fixedByteCount` is given the result is truncated or zero padded to that size.
    public mutating func writeUTF16LE(_ string: String, fixedByteCount: Int? = nil, nullTerminated: Bool = false) {
        var encoded: [UInt8] = []
        for unit in string.utf16 {
            encoded.append(UInt8(truncatingIfNeeded: unit))
            encoded.append(UInt8(truncatingIfNeeded: unit >> 8))
        }
        if nullTerminated {
            encoded.append(contentsOf: [0, 0])
        }
        if let fixedByteCount {
            if encoded.count > fixedByteCount {
                encoded = Array(encoded.prefix(max(fixedByteCount - 2, 0))) + [0, 0]
            }
            encoded.append(contentsOf: repeatElement(0, count: fixedByteCount - encoded.count))
        }
        bytes.append(contentsOf: encoded)
    }

    public mutating func setUInt16LE(_ value: UInt16, at offset: Int) {
        bytes[offset] = UInt8(truncatingIfNeeded: value)
        bytes[offset + 1] = UInt8(truncatingIfNeeded: value >> 8)
    }

    public mutating func setUInt16BE(_ value: UInt16, at offset: Int) {
        bytes[offset] = UInt8(truncatingIfNeeded: value >> 8)
        bytes[offset + 1] = UInt8(truncatingIfNeeded: value)
    }
}
