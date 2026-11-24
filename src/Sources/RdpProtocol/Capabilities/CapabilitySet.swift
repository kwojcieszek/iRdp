/// A raw capability set: type and body (without the 4-byte header).
public struct CapabilitySet: Sendable, Equatable {
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

    static func parseAll(_ reader: inout ByteReader, count: Int) throws -> [CapabilitySet] {
        var sets: [CapabilitySet] = []
        for _ in 0..<count {
            guard reader.remaining >= 4 else { break }
            let type = try reader.readUInt16LE()
            let length = Int(try reader.readUInt16LE())
            guard length >= 4 else { throw RdpProtocolError.invalidValue("capability length \(length)") }
            sets.append(CapabilitySet(type: type, body: try reader.readBytes(min(length - 4, reader.remaining))))
        }
        return sets
    }
}
