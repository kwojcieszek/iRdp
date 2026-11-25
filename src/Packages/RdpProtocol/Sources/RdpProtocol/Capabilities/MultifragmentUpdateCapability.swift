/// TS_MULTIFRAGMENTUPDATE_CAPABILITYSET.
public struct MultifragmentUpdateCapability: Sendable, Equatable {
    public var maxRequestSize: UInt32

    public init(maxRequestSize: UInt32) {
        self.maxRequestSize = maxRequestSize
    }

    public func encode() -> CapabilitySet {
        var writer = ByteWriter()
        writer.writeUInt32LE(maxRequestSize)
        return CapabilitySet(type: CapabilitySetType.multifragmentUpdate, body: writer.bytes)
    }

    public static func parse(_ body: [UInt8]) throws -> MultifragmentUpdateCapability {
        var reader = ByteReader(body)
        return MultifragmentUpdateCapability(maxRequestSize: try reader.readUInt32LE())
    }
}
