/// Pointer flags of mouse input events (MS-RDPBCGR 2.2.8.1.1.3.1.1.3).
public struct PointerFlags: OptionSet, Sendable, Hashable {
    public let rawValue: UInt16

    public init(rawValue: UInt16) {
        self.rawValue = rawValue
    }

    public static let wheelNegative = PointerFlags(rawValue: 0x0100)
    public static let horizontalWheel = PointerFlags(rawValue: 0x0400)
    public static let wheel = PointerFlags(rawValue: 0x0200)
    public static let move = PointerFlags(rawValue: 0x0800)
    public static let button1 = PointerFlags(rawValue: 0x1000)
    public static let button2 = PointerFlags(rawValue: 0x2000)
    public static let button3 = PointerFlags(rawValue: 0x4000)
    public static let down = PointerFlags(rawValue: 0x8000)

    /// Signed wheel rotation (positive = away from the user / right), in units of 1/120 notch.
    public var wheelRotation: Int {
        let magnitude = Int(rawValue & 0x00FF)
        return contains(.wheelNegative) ? magnitude - 0x100 : magnitude
    }
}
