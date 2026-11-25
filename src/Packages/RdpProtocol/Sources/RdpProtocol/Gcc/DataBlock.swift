/// A raw GCC user data block: 16-bit type, 16-bit length (including the header) and body.
public struct DataBlock: Sendable, Equatable {
    public var type: UInt16
    public var body: [UInt8]

    public init(type: UInt16, body: [UInt8]) {
        self.type = type
        self.body = body
    }

    public func encode() -> [UInt8] {
        var writer = ByteWriter(capacity: body.count + 4)
        writer.writeUInt16LE(type)
        writer.writeUInt16LE(UInt16(body.count + 4))
        writer.writeBytes(body)
        return writer.bytes
    }

    public static func parseAll(_ bytes: [UInt8]) throws -> [DataBlock] {
        var reader = ByteReader(bytes)
        var blocks: [DataBlock] = []
        while reader.remaining >= 4 {
            let type = try reader.readUInt16LE()
            let length = Int(try reader.readUInt16LE())
            guard length >= 4 else { throw RdpProtocolError.invalidValue("data block length \(length)") }
            blocks.append(DataBlock(type: type, body: try reader.readBytes(length - 4)))
        }
        return blocks
    }
}
