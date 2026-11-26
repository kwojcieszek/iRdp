/// Flags of the basic security header (MS-RDPBCGR 2.2.8.1.1.2.1).
public struct SecurityHeaderFlags: OptionSet, Sendable {
    public let rawValue: UInt16

    public init(rawValue: UInt16) {
        self.rawValue = rawValue
    }

    public static let exchangePacket = SecurityHeaderFlags(rawValue: 0x0001)
    public static let transportRequest = SecurityHeaderFlags(rawValue: 0x0002)
    public static let transportResponse = SecurityHeaderFlags(rawValue: 0x0004)
    public static let encrypt = SecurityHeaderFlags(rawValue: 0x0008)
    public static let infoPacket = SecurityHeaderFlags(rawValue: 0x0040)
    public static let licensePacket = SecurityHeaderFlags(rawValue: 0x0080)
    public static let redirectionPacket = SecurityHeaderFlags(rawValue: 0x0400)
    public static let autodetectRequest = SecurityHeaderFlags(rawValue: 0x1000)
    public static let autodetectResponse = SecurityHeaderFlags(rawValue: 0x2000)
    public static let heartbeat = SecurityHeaderFlags(rawValue: 0x4000)
}
