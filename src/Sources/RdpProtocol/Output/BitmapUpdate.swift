/// TS_UPDATE_BITMAP_DATA: a list of bitmap rectangles.
public struct BitmapUpdate: Sendable, Equatable {
    public static let updateTypeBitmap: UInt16 = 0x0001

    public var rectangles: [BitmapRectangle]

    public init(rectangles: [BitmapRectangle]) {
        self.rectangles = rectangles
    }

    public func encode() -> [UInt8] {
        var writer = ByteWriter(capacity: rectangles.reduce(4) { $0 + $1.data.count + BitmapRectangle.headerLength })
        writer.writeUInt16LE(Self.updateTypeBitmap)
        writer.writeUInt16LE(UInt16(rectangles.count))
        rectangles.forEach { $0.encode(into: &writer) }
        return writer.bytes
    }

    public static func parse(_ data: [UInt8]) throws -> BitmapUpdate {
        var reader = ByteReader(data)
        guard try reader.readUInt16LE() == updateTypeBitmap else { throw RdpProtocolError.invalidValue("bitmap update type") }
        let count = Int(try reader.readUInt16LE())
        return BitmapUpdate(rectangles: try (0..<count).map { _ in try BitmapRectangle.parse(&reader) })
    }
}
