/// TS_FONT_LIST_PDU body sent by the client during finalization.
public enum FontListPdu {
    public static func encode() -> [UInt8] {
        var writer = ByteWriter()
        writer.writeUInt16LE(0)
        writer.writeUInt16LE(0)
        writer.writeUInt16LE(0x0003)
        writer.writeUInt16LE(0x0032)
        return writer.bytes
    }
}
