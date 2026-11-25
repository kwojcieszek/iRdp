/// TS_INPUT_CAPABILITYSET.
public struct InputCapability: Sendable, Equatable {
    public static let scancodes: UInt16 = 0x0001
    public static let mouseExtended: UInt16 = 0x0004
    public static let fastPathInput: UInt16 = 0x0008
    public static let unicode: UInt16 = 0x0010
    public static let fastPathInput2: UInt16 = 0x0020
    public static let unused1: UInt16 = 0x0040
    public static let mouseHorizontalWheel: UInt16 = 0x0100
    public static let qoeTimestamps: UInt16 = 0x0200
    public static let mouseRelative: UInt16 = 0x0400

    public var flags: UInt16
    public var keyboardLayout: UInt32

    public init(flags: UInt16, keyboardLayout: UInt32 = 0) {
        self.flags = flags
        self.keyboardLayout = keyboardLayout
    }

    public static let serverDefault = InputCapability(flags: scancodes | mouseExtended | fastPathInput | unicode | fastPathInput2 | mouseHorizontalWheel)

    public func encode() -> CapabilitySet {
        var writer = ByteWriter()
        writer.writeUInt16LE(flags)
        writer.writeUInt16LE(0)
        writer.writeUInt32LE(keyboardLayout)
        writer.writeUInt32LE(0)
        writer.writeUInt32LE(0)
        writer.writeUInt32LE(0)
        writer.writeZeros(64)
        return CapabilitySet(type: CapabilitySetType.input, body: writer.bytes)
    }

    public static func parse(_ body: [UInt8]) throws -> InputCapability {
        var reader = ByteReader(body)
        let flags = try reader.readUInt16LE()
        try reader.skip(2)
        return InputCapability(flags: flags, keyboardLayout: reader.remaining >= 4 ? try reader.readUInt32LE() : 0)
    }
}
