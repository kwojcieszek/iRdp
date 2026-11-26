/// Minimal DER writer for the CredSSP and SPNEGO structures.
enum Der {
    static func length(_ value: Int) -> [UInt8] {
        if value < 0x80 { return [UInt8(value)] }
        if value <= 0xFF { return [0x81, UInt8(value)] }
        if value <= 0xFFFF { return [0x82, UInt8(value >> 8), UInt8(truncatingIfNeeded: value)] }
        return [0x83, UInt8(value >> 16), UInt8(truncatingIfNeeded: value >> 8), UInt8(truncatingIfNeeded: value)]
    }

    static func tlv(_ tag: UInt8, _ content: [UInt8]) -> [UInt8] { [tag] + length(content.count) + content }
    static func sequence(_ content: [UInt8]) -> [UInt8] { tlv(0x30, content) }
    static func context(_ number: UInt8, _ content: [UInt8]) -> [UInt8] { tlv(0xA0 | number, content) }
    static func octetString(_ content: [UInt8]) -> [UInt8] { tlv(0x04, content) }

    static func integer(_ value: Int) -> [UInt8] {
        var bytes: [UInt8] = []
        var remaining = value
        repeat {
            bytes.insert(UInt8(truncatingIfNeeded: remaining), at: 0)
            remaining >>= 8
        } while remaining > 0
        if bytes[0] & 0x80 != 0 { bytes.insert(0, at: 0) }
        return tlv(0x02, bytes)
    }

    static func enumerated(_ value: UInt8) -> [UInt8] { tlv(0x0A, [value]) }
}
