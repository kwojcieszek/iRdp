/// Dynamic virtual channel PDUs carried on the "drdynvc" static channel (MS-RDPEDYC 2.2).
public enum DynamicChannelPdu: Sendable, Equatable {
    case capabilities(version: UInt16)
    case createRequest(channelId: UInt32, name: String)
    case createResponse(channelId: UInt32, status: Int32)
    case dataFirst(channelId: UInt32, totalLength: Int, data: [UInt8])
    case data(channelId: UInt32, data: [UInt8])
    case close(channelId: UInt32)

    /// Largest DVC PDU; bigger messages are split into DATA_FIRST and DATA PDUs.
    public static let maximumPduLength = 1600

    enum Command: UInt8 {
        case create = 0x01
        case dataFirst = 0x02
        case data = 0x03
        case close = 0x04
        case capabilities = 0x05
    }

    public static func parse(_ bytes: [UInt8]) throws -> DynamicChannelPdu {
        var reader = ByteReader(bytes)
        let header = try reader.readUInt8()
        let channelIdSize = Int(header & 0x03)
        let lengthSize = Int((header >> 2) & 0x03)
        guard let command = Command(rawValue: header >> 4) else { throw RdpProtocolError.unsupported("DVC command \(header >> 4)") }
        switch command {
        case .capabilities:
            try reader.skip(1)
            return .capabilities(version: try reader.readUInt16LE())
        case .create:
            let id = try readVariable(&reader, size: channelIdSize)
            if reader.remaining == 4 {
                return .createResponse(channelId: id, status: Int32(bitPattern: try reader.readUInt32LE()))
            }
            let name = String(decoding: reader.readRemainingBytes().prefix { $0 != 0 }, as: UTF8.self)
            return .createRequest(channelId: id, name: name)
        case .dataFirst:
            let id = try readVariable(&reader, size: channelIdSize)
            let total = Int(try readVariable(&reader, size: lengthSize))
            return .dataFirst(channelId: id, totalLength: total, data: reader.readRemainingBytes())
        case .data:
            let id = try readVariable(&reader, size: channelIdSize)
            return .data(channelId: id, data: reader.readRemainingBytes())
        case .close:
            return .close(channelId: try readVariable(&reader, size: channelIdSize))
        }
    }

    public func encode() -> [UInt8] {
        var writer = ByteWriter()
        switch self {
        case .capabilities(let version):
            writer.writeUInt8(Command.capabilities.rawValue << 4)
            writer.writeUInt8(0)
            writer.writeUInt16LE(version)
        case .createRequest(let id, let name):
            writer.writeUInt8(Command.create.rawValue << 4 | Self.sizeCode(id))
            Self.writeVariable(&writer, id)
            writer.writeBytes(Array(name.utf8))
            writer.writeUInt8(0)
        case .createResponse(let id, let status):
            writer.writeUInt8(Command.create.rawValue << 4 | Self.sizeCode(id))
            Self.writeVariable(&writer, id)
            writer.writeUInt32LE(UInt32(bitPattern: status))
        case .dataFirst(let id, let total, let data):
            writer.writeUInt8(Command.dataFirst.rawValue << 4 | Self.sizeCode(UInt32(total)) << 2 | Self.sizeCode(id))
            Self.writeVariable(&writer, id)
            Self.writeVariable(&writer, UInt32(total))
            writer.writeBytes(data)
        case .data(let id, let data):
            writer.writeUInt8(Command.data.rawValue << 4 | Self.sizeCode(id))
            Self.writeVariable(&writer, id)
            writer.writeBytes(data)
        case .close(let id):
            writer.writeUInt8(Command.close.rawValue << 4 | Self.sizeCode(id))
            Self.writeVariable(&writer, id)
        }
        return writer.bytes
    }

    /// Encodes a message as one DATA PDU, or DATA_FIRST followed by DATA PDUs, each at most `maximumPduLength` bytes.
    public static func fragments(channelId: UInt32, message: [UInt8], maximumPduLength: Int = maximumPduLength) -> [[UInt8]] {
        let idLength = variableLength(sizeCode(channelId))
        let single = maximumPduLength - 1 - idLength
        if message.count <= single {
            return [DynamicChannelPdu.data(channelId: channelId, data: message).encode()]
        }
        let firstCapacity = single - variableLength(sizeCode(UInt32(message.count)))
        var pdus = [DynamicChannelPdu.dataFirst(channelId: channelId, totalLength: message.count, data: Array(message[0..<firstCapacity])).encode()]
        var offset = firstCapacity
        while offset < message.count {
            let end = min(offset + single, message.count)
            pdus.append(DynamicChannelPdu.data(channelId: channelId, data: Array(message[offset..<end])).encode())
            offset = end
        }
        return pdus
    }

    static func sizeCode(_ value: UInt32) -> UInt8 {
        value <= 0xFF ? 0 : value <= 0xFFFF ? 1 : 2
    }

    static func variableLength(_ code: UInt8) -> Int {
        code == 0 ? 1 : code == 1 ? 2 : 4
    }

    static func writeVariable(_ writer: inout ByteWriter, _ value: UInt32) {
        switch sizeCode(value) {
        case 0: writer.writeUInt8(UInt8(value))
        case 1: writer.writeUInt16LE(UInt16(value))
        default: writer.writeUInt32LE(value)
        }
    }

    static func readVariable(_ reader: inout ByteReader, size: Int) throws -> UInt32 {
        switch size {
        case 0: return UInt32(try reader.readUInt8())
        case 1: return UInt32(try reader.readUInt16LE())
        default: return try reader.readUInt32LE()
        }
    }
}
