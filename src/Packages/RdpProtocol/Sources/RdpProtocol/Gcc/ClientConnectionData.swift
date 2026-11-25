/// Client data blocks sent in the GCC Conference Create Request.
public struct ClientConnectionData: Sendable, Equatable {
    public var core: ClientCoreData
    public var network: ClientNetworkData

    public init(core: ClientCoreData, network: ClientNetworkData) {
        self.core = core
        self.network = network
    }

    public static func parse(_ blocks: [DataBlock]) throws -> ClientConnectionData {
        guard let coreBlock = blocks.first(where: { $0.type == DataBlockType.clientCore }) else {
            throw RdpProtocolError.invalidValue("missing client core data")
        }
        let network = try blocks.first(where: { $0.type == DataBlockType.clientNetwork }).map { try ClientNetworkData.parse($0.body) }
        return ClientConnectionData(core: try ClientCoreData.parse(coreBlock.body), network: network ?? ClientNetworkData(channels: []))
    }

    public func encodeBlocks() -> [UInt8] {
        var security = ByteWriter()
        security.writeUInt32LE(0)
        security.writeUInt32LE(0)
        return core.encode().encode() + DataBlock(type: DataBlockType.clientSecurity, body: security.bytes).encode() + network.encode().encode()
    }
}
