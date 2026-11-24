/// TS_UD_CS_CORE client core data (MS-RDPBCGR 2.2.1.3.2).
public struct ClientCoreData: Sendable, Equatable {
    public static let supports32BitsPerPixel: UInt16 = 0x0008
    public static let wants32BitsPerPixelSession: UInt16 = 0x0002

    public var version: UInt32
    public var desktopWidth: UInt16
    public var desktopHeight: UInt16
    public var keyboardLayout: UInt32
    public var clientBuild: UInt32
    public var clientName: String
    public var keyboardType: UInt32
    public var keyboardSubType: UInt32
    public var keyboardFunctionKeys: UInt32
    public var highColorDepth: UInt16?
    public var supportedColorDepths: UInt16?
    public var earlyCapabilityFlags: UInt16?
    public var serverSelectedProtocol: UInt32?

    public init(version: UInt32 = RdpVersion.rdp10_0, desktopWidth: UInt16, desktopHeight: UInt16, keyboardLayout: UInt32 = 0x409, clientBuild: UInt32 = 0, clientName: String, keyboardType: UInt32 = 4, keyboardSubType: UInt32 = 0, keyboardFunctionKeys: UInt32 = 12, highColorDepth: UInt16? = 24, supportedColorDepths: UInt16? = 0x000F, earlyCapabilityFlags: UInt16? = 0x0002, serverSelectedProtocol: UInt32? = 1) {
        self.version = version
        self.desktopWidth = desktopWidth
        self.desktopHeight = desktopHeight
        self.keyboardLayout = keyboardLayout
        self.clientBuild = clientBuild
        self.clientName = clientName
        self.keyboardType = keyboardType
        self.keyboardSubType = keyboardSubType
        self.keyboardFunctionKeys = keyboardFunctionKeys
        self.highColorDepth = highColorDepth
        self.supportedColorDepths = supportedColorDepths
        self.earlyCapabilityFlags = earlyCapabilityFlags
        self.serverSelectedProtocol = serverSelectedProtocol
    }

    public static func parse(_ body: [UInt8]) throws -> ClientCoreData {
        var reader = ByteReader(body)
        let version = try reader.readUInt32LE()
        let width = try reader.readUInt16LE()
        let height = try reader.readUInt16LE()
        try reader.skip(4)
        let layout = try reader.readUInt32LE()
        let build = try reader.readUInt32LE()
        let name = try reader.readUTF16LE(byteCount: 32)
        let type = try reader.readUInt32LE()
        let subType = try reader.readUInt32LE()
        let functionKeys = try reader.readUInt32LE()
        try reader.skip(64)
        var data = ClientCoreData(version: version, desktopWidth: width, desktopHeight: height, keyboardLayout: layout, clientBuild: build, clientName: name, keyboardType: type, keyboardSubType: subType, keyboardFunctionKeys: functionKeys, highColorDepth: nil, supportedColorDepths: nil, earlyCapabilityFlags: nil, serverSelectedProtocol: nil)
        guard reader.remaining >= 8 else { return data }
        try reader.skip(8)
        guard reader.remaining >= 2 else { return data }
        data.highColorDepth = try reader.readUInt16LE()
        guard reader.remaining >= 2 else { return data }
        data.supportedColorDepths = try reader.readUInt16LE()
        guard reader.remaining >= 2 else { return data }
        data.earlyCapabilityFlags = try reader.readUInt16LE()
        guard reader.remaining >= 64 + 2 + 4 else { return data }
        try reader.skip(66)
        data.serverSelectedProtocol = try reader.readUInt32LE()
        return data
    }

    public func encode() -> DataBlock {
        var writer = ByteWriter(capacity: 216)
        writer.writeUInt32LE(version)
        writer.writeUInt16LE(desktopWidth)
        writer.writeUInt16LE(desktopHeight)
        writer.writeUInt16LE(0xCA01)
        writer.writeUInt16LE(0xAA03)
        writer.writeUInt32LE(keyboardLayout)
        writer.writeUInt32LE(clientBuild)
        writer.writeUTF16LE(clientName, fixedByteCount: 32)
        writer.writeUInt32LE(keyboardType)
        writer.writeUInt32LE(keyboardSubType)
        writer.writeUInt32LE(keyboardFunctionKeys)
        writer.writeZeros(64)
        writer.writeUInt16LE(0xCA01)
        writer.writeUInt16LE(1)
        writer.writeUInt32LE(0)
        writer.writeUInt16LE(highColorDepth ?? 24)
        writer.writeUInt16LE(supportedColorDepths ?? 0x000F)
        writer.writeUInt16LE(earlyCapabilityFlags ?? 0)
        writer.writeZeros(64)
        writer.writeUInt8(0)
        writer.writeUInt8(0)
        writer.writeUInt32LE(serverSelectedProtocol ?? 0)
        return DataBlock(type: DataBlockType.clientCore, body: writer.bytes)
    }
}
