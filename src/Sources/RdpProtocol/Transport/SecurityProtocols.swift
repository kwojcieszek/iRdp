/// Security protocols negotiated in RDP_NEG_REQ / RDP_NEG_RSP (MS-RDPBCGR 2.2.1.1.1).
public struct SecurityProtocols: OptionSet, Sendable, Hashable {
    public let rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    /// Standard RDP security (no flag set).
    public static let standardRdp: SecurityProtocols = []
    public static let tls = SecurityProtocols(rawValue: 0x0000_0001)
    public static let credSsp = SecurityProtocols(rawValue: 0x0000_0002)
    public static let rdsTls = SecurityProtocols(rawValue: 0x0000_0004)
    public static let credSspWithEarlyUserAuthorization = SecurityProtocols(rawValue: 0x0000_0008)
    public static let rdsAad = SecurityProtocols(rawValue: 0x0000_0010)
}
