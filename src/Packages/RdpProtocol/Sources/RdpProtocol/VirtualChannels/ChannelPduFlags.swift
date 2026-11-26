/// Flags of CHANNEL_PDU_HEADER (MS-RDPBCGR 2.2.6.1.1).
public enum ChannelPduFlags {
    public static let first: UInt32 = 0x0000_0001
    public static let last: UInt32 = 0x0000_0002
    public static let showProtocol: UInt32 = 0x0000_0010
}
