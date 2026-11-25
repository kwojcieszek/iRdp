/// TS_FONT_MAP_PDU body sent by the server to finish the connection finalization.
public enum FontMapPdu {
    public static func encode() -> [UInt8] {
        var writer = ByteWriter()
        writer.writeUInt16LE(0)
        writer.writeUInt16LE(0)
        writer.writeUInt16LE(0x0003)
        writer.writeUInt16LE(0x0004)
        return writer.bytes
    }
}
