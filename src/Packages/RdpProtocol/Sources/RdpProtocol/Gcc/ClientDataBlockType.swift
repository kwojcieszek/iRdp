/// Types of client and server data blocks in GCC user data (MS-RDPBCGR 2.2.1.3 / 2.2.1.4).
public enum DataBlockType {
    public static let clientCore: UInt16 = 0xC001
    public static let clientSecurity: UInt16 = 0xC002
    public static let clientNetwork: UInt16 = 0xC003
    public static let clientCluster: UInt16 = 0xC004
    public static let clientMonitor: UInt16 = 0xC005
    public static let clientMessageChannel: UInt16 = 0xC006
    public static let clientMonitorExtended: UInt16 = 0xC008
    public static let clientMultitransport: UInt16 = 0xC00A
    public static let serverCore: UInt16 = 0x0C01
    public static let serverSecurity: UInt16 = 0x0C02
    public static let serverNetwork: UInt16 = 0x0C03
    public static let serverMessageChannel: UInt16 = 0x0C04
    public static let serverMultitransport: UInt16 = 0x0C08
}
