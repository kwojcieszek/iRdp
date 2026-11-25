/// Reassembles DVC messages split into DATA_FIRST and DATA PDUs.
public struct DynamicChannelReassembler: Sendable {
    private var buffers: [UInt32: (expected: Int, data: [UInt8])] = [:]

    public init() {}

    /// Returns the channel id and complete message, or nil while more fragments are expected.
    public mutating func append(_ pdu: DynamicChannelPdu) -> (channelId: UInt32, message: [UInt8])? {
        switch pdu {
        case .dataFirst(let id, let total, let data):
            if data.count >= total { return (id, data) }
            buffers[id] = (total, data)
            return nil
        case .data(let id, let data):
            guard var pending = buffers[id] else { return (id, data) }
            pending.data.append(contentsOf: data)
            if pending.data.count >= pending.expected {
                buffers[id] = nil
                return (id, pending.data)
            }
            buffers[id] = pending
            return nil
        default:
            return nil
        }
    }
}
