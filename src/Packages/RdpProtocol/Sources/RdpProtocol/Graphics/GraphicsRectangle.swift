/// RDPGFX_RECT16 with exclusive right and bottom edges.
public struct GraphicsRectangle: Sendable, Equatable {
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

    func encode(into writer: inout ByteWriter) {
        writer.writeUInt16LE(left)
        writer.writeUInt16LE(top)
        writer.writeUInt16LE(right)
        writer.writeUInt16LE(bottom)
    }

    static func parse(_ reader: inout ByteReader) throws -> GraphicsRectangle {
        GraphicsRectangle(left: try reader.readUInt16LE(), top: try reader.readUInt16LE(), right: try reader.readUInt16LE(), bottom: try reader.readUInt16LE())
    }
}
