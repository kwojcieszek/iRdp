/// Encodes the subset of ASN.1 BER used by MCS connect PDUs (T.125).
public enum BerEncoder {
    public static func length(_ value: Int) -> [UInt8] {
        if value < 0x80 { return [UInt8(value)] }
        if value <= 0xFF { return [0x81, UInt8(value)] }
        return [0x82, UInt8(truncatingIfNeeded: value >> 8), UInt8(truncatingIfNeeded: value)]
    }

    public static func tagged(_ tag: [UInt8], _ content: [UInt8]) -> [UInt8] {
        tag + length(content.count) + content
    }

    public static func integer(_ value: Int) -> [UInt8] {
        var content: [UInt8] = []
        var remaining = value
        repeat {
            content.insert(UInt8(truncatingIfNeeded: remaining), at: 0)
            remaining >>= 8
        } while remaining > 0
        if content[0] & 0x80 != 0 { content.insert(0, at: 0) }
        return tagged([BerTag.integer], content)
    }

    public static func enumerated(_ value: UInt8) -> [UInt8] {
        tagged([BerTag.enumerated], [value])
    }

    public static func boolean(_ value: Bool) -> [UInt8] {
        tagged([BerTag.boolean], [value ? 0xFF : 0x00])
    }

    public static func octetString(_ value: [UInt8]) -> [UInt8] {
        tagged([BerTag.octetString], value)
    }

    public static func sequence(_ content: [UInt8]) -> [UInt8] {
        tagged([BerTag.sequence], content)
    }

    /// Application tag in high-tag-number form, e.g. 101 (Connect-Initial) becomes `7F 65`.
    public static func applicationTag(_ number: UInt8) -> [UInt8] {
        [0x7F, number]
    }
}
