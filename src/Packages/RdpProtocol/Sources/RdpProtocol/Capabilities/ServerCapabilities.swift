/// Builds the capability sets advertised by the server in the Demand Active PDU.
public enum ServerCapabilities {
    public static func make(desktopWidth: UInt16, desktopHeight: UInt16, bitsPerPixel: UInt16) -> [CapabilitySet] {
        [
            GeneralCapability(extraFlags: GeneralCapability.fastPathOutputSupported | GeneralCapability.longCredentialsSupported | GeneralCapability.noBitmapCompressionHeader).encode(),
            BitmapCapability(preferredBitsPerPixel: bitsPerPixel, desktopWidth: desktopWidth, desktopHeight: desktopHeight).encode(),
            orderCapability(),
            pointerCapability(),
            InputCapability.serverDefault.encode(),
            virtualChannelCapability(),
            fontCapability(),
            shareCapability(),
            MultifragmentUpdateCapability(maxRequestSize: 0x0040_0000).encode(),
        ]
    }

    static func orderCapability() -> CapabilitySet {
        var writer = ByteWriter()
        writer.writeZeros(16)
        writer.writeUInt32LE(0)
        writer.writeUInt16LE(1)
        writer.writeUInt16LE(20)
        writer.writeUInt16LE(0)
        writer.writeUInt16LE(1)
        writer.writeUInt16LE(0)
        writer.writeUInt16LE(0x0022)
        var orders = [UInt8](repeating: 0, count: 32)
        orders[2] = 1 // TS_NEG_SCRBLT_INDEX
        writer.writeBytes(orders)
        writer.writeUInt16LE(0)
        writer.writeUInt16LE(0)
        writer.writeUInt32LE(0)
        writer.writeUInt32LE(0)
        writer.writeUInt16LE(0)
        writer.writeUInt16LE(0)
        writer.writeUInt16LE(0)
        writer.writeUInt16LE(0)
        return CapabilitySet(type: CapabilitySetType.order, body: writer.bytes)
    }

    static func pointerCapability() -> CapabilitySet {
        var writer = ByteWriter()
        writer.writeUInt16LE(1)
        writer.writeUInt16LE(25)
        writer.writeUInt16LE(25)
        return CapabilitySet(type: CapabilitySetType.pointer, body: writer.bytes)
    }

    static func virtualChannelCapability() -> CapabilitySet {
        var writer = ByteWriter()
        writer.writeUInt32LE(0)
        writer.writeUInt32LE(1600)
        return CapabilitySet(type: CapabilitySetType.virtualChannel, body: writer.bytes)
    }

    static func fontCapability() -> CapabilitySet {
        var writer = ByteWriter()
        writer.writeUInt16LE(1)
        writer.writeUInt16LE(0)
        return CapabilitySet(type: CapabilitySetType.font, body: writer.bytes)
    }

    static func shareCapability() -> CapabilitySet {
        var writer = ByteWriter()
        writer.writeUInt16LE(McsChannel.serverChannelId)
        writer.writeUInt16LE(0)
        return CapabilitySet(type: CapabilitySetType.share, body: writer.bytes)
    }
}
