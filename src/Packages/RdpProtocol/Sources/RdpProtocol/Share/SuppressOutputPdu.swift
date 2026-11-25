/// TS_SUPPRESS_OUTPUT_PDU body: the client minimized or restored its window.
public struct SuppressOutputPdu: Sendable, Equatable {
    public var allowDisplayUpdates: Bool

    public init(allowDisplayUpdates: Bool) {
        self.allowDisplayUpdates = allowDisplayUpdates
    }

    public static func parse(_ body: [UInt8]) throws -> SuppressOutputPdu {
        var reader = ByteReader(body)
        return SuppressOutputPdu(allowDisplayUpdates: try reader.readUInt8() != 0)
    }
}
