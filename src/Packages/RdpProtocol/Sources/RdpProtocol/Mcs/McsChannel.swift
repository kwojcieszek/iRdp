/// Well known MCS channel identifiers.
public enum McsChannel {
    /// Base value subtracted from user ids in PER encoded domain PDUs.
    public static let userIdBase: UInt16 = 1001
    /// Identifier the server uses as share control pdu source.
    public static let serverChannelId: UInt16 = 1002
    /// MCS I/O (global) channel.
    public static let ioChannelId: UInt16 = 1003
    /// First identifier assigned to static virtual channels.
    public static let firstStaticChannelId: UInt16 = 1004
}
