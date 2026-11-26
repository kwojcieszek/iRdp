/// TS_UD_CS_NET client network data listing requested static virtual channels.
public struct ClientNetworkData: Sendable, Equatable {
    public var channels: [ChannelDefinition]

    public init(channels: [ChannelDefinition]) {
        self.channels = channels
    }

    public static func parse(_ body: [UInt8]) throws -> ClientNetworkData {
        var reader = ByteReader(body)
        let count = Int(try reader.readUInt32LE())
        guard count <= 31 else { throw RdpProtocolError.invalidValue("channel count \(count)") }
        var channels: [ChannelDefinition] = []
        for _ in 0..<count {
            let name = try reader.readASCII(byteCount: 8)
            channels.append(ChannelDefinition(name: name, options: try reader.readUInt32LE()))
        }
        return ClientNetworkData(channels: channels)
    }

    public func encode() -> DataBlock {
        var writer = ByteWriter()
        writer.writeUInt32LE(UInt32(channels.count))
        for channel in channels {
            let name = Array(channel.name.utf8.prefix(7))
            writer.writeBytes(name)
            writer.writeZeros(8 - name.count)
            writer.writeUInt32LE(channel.options)
        }
        return DataBlock(type: DataBlockType.clientNetwork, body: writer.bytes)
    }
}
