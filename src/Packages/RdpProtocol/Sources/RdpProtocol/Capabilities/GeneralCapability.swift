/// TS_GENERAL_CAPABILITYSET.
public struct GeneralCapability: Sendable, Equatable {
    public static let fastPathOutputSupported: UInt16 = 0x0001
    public static let longCredentialsSupported: UInt16 = 0x0004
    public static let autoReconnectSupported: UInt16 = 0x0008
    public static let encryptedSaltedChecksum: UInt16 = 0x0010
    public static let noBitmapCompressionHeader: UInt16 = 0x0400

    public var extraFlags: UInt16
    public var refreshRectSupport: Bool
    public var suppressOutputSupport: Bool

    public init(extraFlags: UInt16, refreshRectSupport: Bool = true, suppressOutputSupport: Bool = true) {
        self.extraFlags = extraFlags
        self.refreshRectSupport = refreshRectSupport
        self.suppressOutputSupport = suppressOutputSupport
    }

    public var supportsFastPathOutput: Bool { extraFlags & Self.fastPathOutputSupported != 0 }

    public func encode() -> CapabilitySet {
        var writer = ByteWriter()
        writer.writeUInt16LE(1)
        writer.writeUInt16LE(3)
        writer.writeUInt16LE(0x0200)
        writer.writeUInt16LE(0)
        writer.writeUInt16LE(0)
        writer.writeUInt16LE(extraFlags)
        writer.writeUInt16LE(0)
        writer.writeUInt16LE(0)
        writer.writeUInt16LE(0)
        writer.writeUInt8(refreshRectSupport ? 1 : 0)
        writer.writeUInt8(suppressOutputSupport ? 1 : 0)
        return CapabilitySet(type: CapabilitySetType.general, body: writer.bytes)
    }

    public static func parse(_ body: [UInt8]) throws -> GeneralCapability {
        var reader = ByteReader(body)
        try reader.skip(10)
        let flags = try reader.readUInt16LE()
        try reader.skip(6)
        let refresh = reader.remaining >= 1 ? try reader.readUInt8() != 0 : false
        let suppress = reader.remaining >= 1 ? try reader.readUInt8() != 0 : false
        return GeneralCapability(extraFlags: flags, refreshRectSupport: refresh, suppressOutputSupport: suppress)
    }
}
