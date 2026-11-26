/// Capability set types (MS-RDPBCGR 2.2.1.13.1.1.1).
public enum CapabilitySetType {
    public static let general: UInt16 = 1
    public static let bitmap: UInt16 = 2
    public static let order: UInt16 = 3
    public static let bitmapCache: UInt16 = 4
    public static let control: UInt16 = 5
    public static let activation: UInt16 = 7
    public static let pointer: UInt16 = 8
    public static let share: UInt16 = 9
    public static let colorCache: UInt16 = 10
    public static let sound: UInt16 = 12
    public static let input: UInt16 = 13
    public static let font: UInt16 = 14
    public static let brush: UInt16 = 15
    public static let glyphCache: UInt16 = 16
    public static let offscreenCache: UInt16 = 17
    public static let bitmapCacheHostSupport: UInt16 = 18
    public static let bitmapCacheV2: UInt16 = 19
    public static let virtualChannel: UInt16 = 20
    public static let multifragmentUpdate: UInt16 = 26
    public static let largePointer: UInt16 = 27
    public static let surfaceCommands: UInt16 = 28
    public static let bitmapCodecs: UInt16 = 29
    public static let frameAcknowledge: UInt16 = 30
}
