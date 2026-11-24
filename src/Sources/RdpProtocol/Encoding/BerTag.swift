/// Universal BER tags used by the MCS layer.
public enum BerTag {
    public static let boolean: UInt8 = 0x01
    public static let integer: UInt8 = 0x02
    public static let octetString: UInt8 = 0x04
    public static let enumerated: UInt8 = 0x0A
    public static let sequence: UInt8 = 0x30
}
