/// TS_BITMAP_CAPABILITYSET describing the session color depth and desktop size.
public struct BitmapCapability: Sendable, Equatable {
    public var preferredBitsPerPixel: UInt16
    public var desktopWidth: UInt16
    public var desktopHeight: UInt16
    public var desktopResizeSupported: Bool

    public init(preferredBitsPerPixel: UInt16, desktopWidth: UInt16, desktopHeight: UInt16, desktopResizeSupported: Bool = true) {
        self.preferredBitsPerPixel = preferredBitsPerPixel
        self.desktopWidth = desktopWidth
        self.desktopHeight = desktopHeight
        self.desktopResizeSupported = desktopResizeSupported
    }

    public func encode() -> CapabilitySet {
        var writer = ByteWriter()
        writer.writeUInt16LE(preferredBitsPerPixel)
        writer.writeUInt16LE(1)
        writer.writeUInt16LE(1)
        writer.writeUInt16LE(1)
        writer.writeUInt16LE(desktopWidth)
        writer.writeUInt16LE(desktopHeight)
        writer.writeUInt16LE(0)
        writer.writeUInt16LE(desktopResizeSupported ? 1 : 0)
        writer.writeUInt16LE(1)
        writer.writeUInt8(0)
        writer.writeUInt8(0x08)
        writer.writeUInt16LE(1)
        writer.writeUInt16LE(0)
        return CapabilitySet(type: CapabilitySetType.bitmap, body: writer.bytes)
    }

    public static func parse(_ body: [UInt8]) throws -> BitmapCapability {
        var reader = ByteReader(body)
        let bpp = try reader.readUInt16LE()
        try reader.skip(6)
        let width = try reader.readUInt16LE()
        let height = try reader.readUInt16LE()
        try reader.skip(2)
        let resize = try reader.readUInt16LE() != 0
        return BitmapCapability(preferredBitsPerPixel: bpp, desktopWidth: width, desktopHeight: height, desktopResizeSupported: resize)
    }
}
