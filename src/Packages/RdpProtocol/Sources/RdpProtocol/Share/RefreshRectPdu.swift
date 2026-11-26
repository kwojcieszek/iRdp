/// TS_REFRESH_RECT_PDU body: areas the client wants redrawn.
public struct RefreshRectPdu: Sendable, Equatable {
    public var areas: [InclusiveRectangle]

    public init(areas: [InclusiveRectangle]) {
        self.areas = areas
    }

    public static func parse(_ body: [UInt8]) throws -> RefreshRectPdu {
        var reader = ByteReader(body)
        let count = Int(try reader.readUInt8())
        try reader.skip(3)
        return RefreshRectPdu(areas: try (0..<count).map { _ in try InclusiveRectangle.parse(&reader) })
    }
}
