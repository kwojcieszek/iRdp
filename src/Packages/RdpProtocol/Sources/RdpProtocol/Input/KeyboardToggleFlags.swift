/// Lock key states carried by synchronize events.
public struct KeyboardToggleFlags: OptionSet, Sendable, Hashable {
    public let rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    public static let scrollLock = KeyboardToggleFlags(rawValue: 0x01)
    public static let numLock = KeyboardToggleFlags(rawValue: 0x02)
    public static let capsLock = KeyboardToggleFlags(rawValue: 0x04)
    public static let kanaLock = KeyboardToggleFlags(rawValue: 0x08)
}
