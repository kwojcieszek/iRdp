/// TS_CONFIRM_ACTIVE_PDU body returned by the client with its capabilities.
public struct ConfirmActivePdu: Sendable, Equatable {
    public var shareId: UInt32
    public var originatorId: UInt16
    public var capabilities: [CapabilitySet]

    public init(shareId: UInt32, originatorId: UInt16 = McsChannel.serverChannelId, capabilities: [CapabilitySet]) {
        self.shareId = shareId
        self.originatorId = originatorId
        self.capabilities = capabilities
    }

    public func capability(_ type: UInt16) -> CapabilitySet? {
        capabilities.first { $0.type == type }
    }

    public static func parse(_ body: [UInt8]) throws -> ConfirmActivePdu {
        var reader = ByteReader(body)
        let shareId = try reader.readUInt32LE()
        let originator = try reader.readUInt16LE()
        let sourceLength = Int(try reader.readUInt16LE())
        _ = try reader.readUInt16LE()
        try reader.skip(sourceLength)
        let count = Int(try reader.readUInt16LE())
        try reader.skip(2)
        return ConfirmActivePdu(shareId: shareId, originatorId: originator, capabilities: try CapabilitySet.parseAll(&reader, count: count))
    }

    public func encode() -> [UInt8] {
        let source = Array("MSTSC".utf8)
        let sets = capabilities.flatMap { $0.encode() }
        var writer = ByteWriter()
        writer.writeUInt32LE(shareId)
        writer.writeUInt16LE(originatorId)
        writer.writeUInt16LE(UInt16(source.count))
        writer.writeUInt16LE(UInt16(sets.count + 4))
        writer.writeBytes(source)
        writer.writeUInt16LE(UInt16(capabilities.count))
        writer.writeUInt16LE(0)
        writer.writeBytes(sets)
        return writer.bytes
    }
}
