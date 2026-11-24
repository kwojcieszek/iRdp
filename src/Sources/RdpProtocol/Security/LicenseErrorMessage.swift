/// Server License Error PDU announcing a valid client (MS-RDPBCGR 2.2.1.12), which skips licensing.
public enum LicenseErrorMessage {
    public static let errorAlertMessageType: UInt8 = 0xFF
    public static let statusValidClient: UInt32 = 0x0000_0007
    public static let stateNoTransition: UInt32 = 0x0000_0002

    public static func validClient() -> [UInt8] {
        var writer = ByteWriter(capacity: 20)
        writer.writeUInt16LE(SecurityHeaderFlags.licensePacket.rawValue)
        writer.writeUInt16LE(0)
        writer.writeUInt8(errorAlertMessageType)
        writer.writeUInt8(0x03)
        writer.writeUInt16LE(16)
        writer.writeUInt32LE(statusValidClient)
        writer.writeUInt32LE(stateNoTransition)
        writer.writeUInt16LE(0x0004)
        writer.writeUInt16LE(0)
        return writer.bytes
    }
}
