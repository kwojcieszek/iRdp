/// Flags of TS_INFO_PACKET (MS-RDPBCGR 2.2.1.11.1.1).
public struct ClientInfoFlags: OptionSet, Sendable {
    public let rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    public static let mouse = ClientInfoFlags(rawValue: 0x0000_0001)
    public static let disableControlAltDelete = ClientInfoFlags(rawValue: 0x0000_0002)
    public static let autoLogon = ClientInfoFlags(rawValue: 0x0000_0008)
    public static let unicode = ClientInfoFlags(rawValue: 0x0000_0010)
    public static let maximizeShell = ClientInfoFlags(rawValue: 0x0000_0020)
    public static let logonNotify = ClientInfoFlags(rawValue: 0x0000_0040)
    public static let enableWindowsKey = ClientInfoFlags(rawValue: 0x0000_0100)
}
