/// TS_DEMAND_ACTIVE_PDU body sent by the server to start capability exchange.
public struct DemandActivePdu: Sendable, Equatable {
    public var shareId: UInt32
    public var capabilities: [CapabilitySet]

    public init(shareId: UInt32, capabilities: [CapabilitySet]) {
        self.shareId = shareId
        self.capabilities = capabilities
    }

    static let sourceDescriptor: [UInt8] = Array("RDP\0".utf8)

    public func encode() -> [UInt8] {
        let sets = capabilities.flatMap { $0.encode() }
        var writer = ByteWriter(capacity: sets.count + 20)
        writer.writeUInt32LE(shareId)
        writer.writeUInt16LE(UInt16(Self.sourceDescriptor.count))
        writer.writeUInt16LE(UInt16(sets.count + 4))
        writer.writeBytes(Self.sourceDescriptor)
        writer.writeUInt16LE(UInt16(capabilities.count))
        writer.writeUInt16LE(0)
        writer.writeBytes(sets)
        writer.writeUInt32LE(0)
        return writer.bytes
    }

    public static func parse(_ body: [UInt8]) throws -> DemandActivePdu {
        var reader = ByteReader(body)
        let shareId = try reader.readUInt32LE()
        let sourceLength = Int(try reader.readUInt16LE())
        _ = try reader.readUInt16LE()
        try reader.skip(sourceLength)
        let count = Int(try reader.readUInt16LE())
        try reader.skip(2)
        return DemandActivePdu(shareId: shareId, capabilities: try CapabilitySet.parseAll(&reader, count: count))
    }
}
