/// Server data blocks (core, security, network) returned in the GCC Conference Create Response.
public struct ServerConnectionData: Sendable, Equatable {
    public var version: UInt32
    public var clientRequestedProtocols: SecurityProtocols
    public var earlyCapabilityFlags: UInt32
    public var ioChannelId: UInt16
    public var staticChannelIds: [UInt16]

    public init(version: UInt32 = RdpVersion.rdp10_0, clientRequestedProtocols: SecurityProtocols, earlyCapabilityFlags: UInt32 = 0, ioChannelId: UInt16 = McsChannel.ioChannelId, staticChannelIds: [UInt16]) {
        self.version = version
        self.clientRequestedProtocols = clientRequestedProtocols
        self.earlyCapabilityFlags = earlyCapabilityFlags
        self.ioChannelId = ioChannelId
        self.staticChannelIds = staticChannelIds
    }

    public func encodeBlocks() -> [UInt8] {
        var core = ByteWriter()
        core.writeUInt32LE(version)
        core.writeUInt32LE(clientRequestedProtocols.rawValue)
        core.writeUInt32LE(earlyCapabilityFlags)
        var security = ByteWriter()
        security.writeUInt32LE(0)
        security.writeUInt32LE(0)
        var network = ByteWriter()
        network.writeUInt16LE(ioChannelId)
        network.writeUInt16LE(UInt16(staticChannelIds.count))
        staticChannelIds.forEach { network.writeUInt16LE($0) }
        if staticChannelIds.count % 2 == 1 { network.writeUInt16LE(0) }
        return DataBlock(type: DataBlockType.serverCore, body: core.bytes).encode()
            + DataBlock(type: DataBlockType.serverSecurity, body: security.bytes).encode()
            + DataBlock(type: DataBlockType.serverNetwork, body: network.bytes).encode()
    }

    public static func parse(_ blocks: [DataBlock]) throws -> ServerConnectionData {
        guard let coreBlock = blocks.first(where: { $0.type == DataBlockType.serverCore }),
              let networkBlock = blocks.first(where: { $0.type == DataBlockType.serverNetwork }) else {
            throw RdpProtocolError.invalidValue("missing server data blocks")
        }
        var core = ByteReader(coreBlock.body)
        let version = try core.readUInt32LE()
        let requested = core.remaining >= 4 ? try core.readUInt32LE() : 0
        let flags = core.remaining >= 4 ? try core.readUInt32LE() : 0
        var network = ByteReader(networkBlock.body)
        let io = try network.readUInt16LE()
        let count = Int(try network.readUInt16LE())
        var ids: [UInt16] = []
        for _ in 0..<count { ids.append(try network.readUInt16LE()) }
        return ServerConnectionData(version: version, clientRequestedProtocols: SecurityProtocols(rawValue: requested), earlyCapabilityFlags: flags, ioChannelId: io, staticChannelIds: ids)
    }
}
