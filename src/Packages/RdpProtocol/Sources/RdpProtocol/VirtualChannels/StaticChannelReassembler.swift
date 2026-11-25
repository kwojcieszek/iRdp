/// Reassembles static virtual channel messages from CHANNEL_PDU_HEADER chunks.
public struct StaticChannelReassembler: Sendable {
    private var buffer: [UInt8] = []
    private var expectedLength = 0

    public init() {}

    /// Adds one chunk and returns the complete message once the last chunk arrived.
    public mutating func append(_ chunk: [UInt8]) throws -> [UInt8]? {
        var reader = ByteReader(chunk)
        let length = Int(try reader.readUInt32LE())
        let flags = try reader.readUInt32LE()
        let data = reader.readRemainingBytes()
        if flags & ChannelPduFlags.first != 0 {
            buffer = []
            buffer.reserveCapacity(length)
            expectedLength = length
        }
        buffer.append(contentsOf: data)
        guard flags & ChannelPduFlags.last != 0 else { return nil }
        defer { buffer = [] }
        guard buffer.count == expectedLength else { throw RdpProtocolError.invalidValue("channel message of \(buffer.count) bytes, expected \(expectedLength)") }
        return buffer
    }
}
