/// Static virtual channel chunks: CHANNEL_PDU_HEADER (total length, flags) followed by chunk data.
public enum StaticChannelPdu {
    public static let defaultChunkLength = 1600

    /// Splits a channel message into chunks no larger than `chunkLength`.
    public static func chunks(for message: [UInt8], chunkLength: Int = defaultChunkLength) -> [[UInt8]] {
        var result: [[UInt8]] = []
        var offset = 0
        repeat {
            let end = min(offset + chunkLength, message.count)
            var flags: UInt32 = 0
            if offset == 0 { flags |= ChannelPduFlags.first }
            if end == message.count { flags |= ChannelPduFlags.last }
            var writer = ByteWriter(capacity: end - offset + 8)
            writer.writeUInt32LE(UInt32(message.count))
            writer.writeUInt32LE(flags)
            writer.writeBytes(message[offset..<end])
            result.append(writer.bytes)
            offset = end
        } while offset < message.count
        return result
    }
}
