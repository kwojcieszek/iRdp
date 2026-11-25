/// Pointer flags of extended mouse events (X buttons).
public struct ExtendedPointerFlags: OptionSet, Sendable, Hashable {
    public let rawValue: UInt16

    public init(rawValue: UInt16) {
        self.rawValue = rawValue
    }

    public static let xButton1 = ExtendedPointerFlags(rawValue: 0x0001)
    public static let xButton2 = ExtendedPointerFlags(rawValue: 0x0002)
    public static let down = ExtendedPointerFlags(rawValue: 0x8000)
}
