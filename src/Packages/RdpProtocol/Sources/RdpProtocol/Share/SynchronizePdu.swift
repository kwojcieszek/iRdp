/// TS_SYNCHRONIZE_PDU body.
public struct SynchronizePdu: Sendable, Equatable {
    public var targetUser: UInt16

    public init(targetUser: UInt16) {
        self.targetUser = targetUser
    }

    public func encode() -> [UInt8] {
        var writer = ByteWriter()
        writer.writeUInt16LE(1)
        writer.writeUInt16LE(targetUser)
        return writer.bytes
    }

    public static func parse(_ body: [UInt8]) throws -> SynchronizePdu {
        var reader = ByteReader(body)
        _ = try reader.readUInt16LE()
        return SynchronizePdu(targetUser: try reader.readUInt16LE())
    }
}
