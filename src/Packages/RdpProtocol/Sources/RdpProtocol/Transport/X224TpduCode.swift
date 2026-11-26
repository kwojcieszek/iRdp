/// X.224 TPDU codes used by RDP.
public enum X224TpduCode {
    public static let connectionRequest: UInt8 = 0xE0
    public static let connectionConfirm: UInt8 = 0xD0
    public static let disconnectRequest: UInt8 = 0x80
    public static let data: UInt8 = 0xF0
}
