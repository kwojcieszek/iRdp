/// RDPGFX PDUs sent by the client.
public enum GraphicsClientPdu: Sendable, Equatable {
    case capsAdvertise([GraphicsCapabilitySet])
    case frameAcknowledge(queueDepth: UInt32, frameId: UInt32, totalFramesDecoded: UInt32)
    case cacheImportOffer
    case other(UInt16)

    /// Queue depth value meaning the client suspends frame acknowledgements.
    public static let suspendFrameAcknowledgement: UInt32 = 0xFFFF_FFFF

    /// Parses all PDUs in a (decompressed) RDPGFX message.
    public static func parseAll(_ message: [UInt8]) throws -> [GraphicsClientPdu] {
        var reader = ByteReader(message)
        var pdus: [GraphicsClientPdu] = []
        while reader.remaining >= 8 {
            let start = reader.offset
            let command = try reader.readUInt16LE()
            _ = try reader.readUInt16LE()
            let length = Int(try reader.readUInt32LE())
            guard length >= 8, start + length <= message.count else { throw RdpProtocolError.invalidValue("RDPGFX length \(length)") }
            var body = ByteReader(try reader.readBytes(length - 8))
            switch GraphicsCommand(rawValue: command) {
            case .capsAdvertise?:
                let count = Int(try body.readUInt16LE())
                var sets: [GraphicsCapabilitySet] = []
                for _ in 0..<count {
                    let version = try body.readUInt32LE()
                    let dataLength = Int(try body.readUInt32LE())
                    let data = try body.readBytes(dataLength)
                    var flagsReader = ByteReader(data)
                    let flags = dataLength >= 4 ? try flagsReader.readUInt32LE() : 0
                    sets.append(GraphicsCapabilitySet(version: version, flags: flags, data: data))
                }
                pdus.append(.capsAdvertise(sets))
            case .frameAcknowledge?:
                pdus.append(.frameAcknowledge(queueDepth: try body.readUInt32LE(), frameId: try body.readUInt32LE(), totalFramesDecoded: try body.readUInt32LE()))
            case .cacheImportOffer?:
                pdus.append(.cacheImportOffer)
            default:
                pdus.append(.other(command))
            }
        }
        return pdus
    }

    /// Encodes the PDU (used by clients and tests).
    public func encode() -> [UInt8] {
        switch self {
        case .capsAdvertise(let sets):
            var writer = ByteWriter()
            writer.writeUInt16LE(UInt16(sets.count))
            sets.forEach { writer.writeBytes($0.encode()) }
            return GraphicsServerPdu.pdu(.capsAdvertise, body: writer.bytes)
        case .frameAcknowledge(let depth, let id, let total):
            var writer = ByteWriter()
            writer.writeUInt32LE(depth)
            writer.writeUInt32LE(id)
            writer.writeUInt32LE(total)
            return GraphicsServerPdu.pdu(.frameAcknowledge, body: writer.bytes)
        case .cacheImportOffer:
            return GraphicsServerPdu.pdu(.cacheImportOffer, body: [0, 0])
        case .other(let command):
            return GraphicsServerPdu.pdu(GraphicsCommand(rawValue: command) ?? .qoeFrameAcknowledge, body: [])
        }
    }
}
