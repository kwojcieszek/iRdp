/// RDPGFX_CAPSET: a graphics pipeline version and its flags.
public struct GraphicsCapabilitySet: Sendable, Equatable {
    public static let version8: UInt32 = 0x0008_0004
    public static let version81: UInt32 = 0x0008_0105
    public static let version10: UInt32 = 0x000A_0002
    public static let version101: UInt32 = 0x000A_0100
    public static let version102: UInt32 = 0x000A_0200
    public static let version103: UInt32 = 0x000A_0301
    public static let version104: UInt32 = 0x000A_0400
    public static let version105: UInt32 = 0x000A_0502
    public static let version106: UInt32 = 0x000A_0600
    public static let version107: UInt32 = 0x000A_0701

    public static let flagThinClient: UInt32 = 0x01
    public static let flagSmallCache: UInt32 = 0x02
    public static let flagAvc420Enabled: UInt32 = 0x10
    public static let flagAvcDisabled: UInt32 = 0x20

    public var version: UInt32
    public var flags: UInt32
    public var data: [UInt8]

    public init(version: UInt32, flags: UInt32, data: [UInt8]? = nil) {
        self.version = version
        self.flags = flags
        if let data {
            self.data = data
        } else {
            var writer = ByteWriter()
            writer.writeUInt32LE(flags)
            self.data = writer.bytes
        }
    }

    /// Whether the client can decode AVC420 (H.264) with this capability set.
    public var supportsAvc420: Bool {
        if version >= Self.version10 { return flags & Self.flagAvcDisabled == 0 }
        if version == Self.version81 { return flags & Self.flagAvc420Enabled != 0 }
        return false
    }

    public func encode() -> [UInt8] {
        var writer = ByteWriter()
        writer.writeUInt32LE(version)
        writer.writeUInt32LE(UInt32(data.count))
        writer.writeBytes(data)
        return writer.bytes
    }

    /// Picks the set to confirm: the newest version, preferring one that allows AVC420.
    public static func choose(from sets: [GraphicsCapabilitySet]) -> GraphicsCapabilitySet? {
        let known = sets.filter { $0.version >= version8 && $0.version <= version107 }
        let ordered = known.sorted { $0.version > $1.version }
        return ordered.first(where: \.supportsAvc420) ?? ordered.first
    }
}
