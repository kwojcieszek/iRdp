/// TS_BITMAP_DATA: one bitmap rectangle with bottom-up rows, raw or compressed.
public struct BitmapRectangle: Sendable, Equatable {
    public static let headerLength = 18
    /// The bitmap data is compressed (interleaved RLE below 32 bpp, planar at 32 bpp).
    public static let compressionFlag: UInt16 = 0x0001
    /// The compressed data has no TS_CD_HEADER.
    public static let noCompressionHeaderFlag: UInt16 = 0x0400

    public var destLeft: UInt16
    public var destTop: UInt16
    public var destRight: UInt16
    public var destBottom: UInt16
    public var width: UInt16
    public var height: UInt16
    public var bitsPerPixel: UInt16
    public var flags: UInt16
    public var data: [UInt8]

    public init(destLeft: UInt16, destTop: UInt16, destRight: UInt16, destBottom: UInt16, width: UInt16, height: UInt16, bitsPerPixel: UInt16, flags: UInt16 = 0, data: [UInt8]) {
        self.destLeft = destLeft
        self.destTop = destTop
        self.destRight = destRight
        self.destBottom = destBottom
        self.width = width
        self.height = height
        self.bitsPerPixel = bitsPerPixel
        self.flags = flags
        self.data = data
    }

    public func encode(into writer: inout ByteWriter) {
        writer.writeUInt16LE(destLeft)
        writer.writeUInt16LE(destTop)
        writer.writeUInt16LE(destRight)
        writer.writeUInt16LE(destBottom)
        writer.writeUInt16LE(width)
        writer.writeUInt16LE(height)
        writer.writeUInt16LE(bitsPerPixel)
        writer.writeUInt16LE(flags)
        writer.writeUInt16LE(UInt16(data.count))
        writer.writeBytes(data)
    }

    static func parse(_ reader: inout ByteReader) throws -> BitmapRectangle {
        let left = try reader.readUInt16LE()
        let top = try reader.readUInt16LE()
        let right = try reader.readUInt16LE()
        let bottom = try reader.readUInt16LE()
        let width = try reader.readUInt16LE()
        let height = try reader.readUInt16LE()
        let bpp = try reader.readUInt16LE()
        let flags = try reader.readUInt16LE()
        let length = Int(try reader.readUInt16LE())
        return BitmapRectangle(destLeft: left, destTop: top, destRight: right, destBottom: bottom, width: width, height: height, bitsPerPixel: bpp, flags: flags, data: try reader.readBytes(length))
    }
}
