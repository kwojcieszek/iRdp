/// TS_RECTANGLE16 with inclusive right and bottom edges.
public struct InclusiveRectangle: Sendable, Equatable {
    public var left: UInt16
    public var top: UInt16
    public var right: UInt16
    public var bottom: UInt16

    public init(left: UInt16, top: UInt16, right: UInt16, bottom: UInt16) {
        self.left = left
        self.top = top
        self.right = right
        self.bottom = bottom
    }

    static func parse(_ reader: inout ByteReader) throws -> InclusiveRectangle {
        InclusiveRectangle(left: try reader.readUInt16LE(), top: try reader.readUInt16LE(), right: try reader.readUInt16LE(), bottom: try reader.readUInt16LE())
    }
}
