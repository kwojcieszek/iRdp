/// One fast-path output update (TS_FP_UPDATE) without compression or fragmentation.
public struct FastPathUpdate: Sendable, Equatable {
    public var code: FastPathUpdateCode
    public var data: [UInt8]

    public init(code: FastPathUpdateCode, data: [UInt8] = []) {
        self.code = code
        self.data = data
    }

    public func encode() -> [UInt8] {
        var writer = ByteWriter(capacity: data.count + 3)
        writer.writeUInt8(code.rawValue)
        writer.writeUInt16LE(UInt16(data.count))
        writer.writeBytes(data)
        return writer.bytes
    }

    /// Wraps updates in one fast-path output PDU.
    public static func pdu(_ updates: [FastPathUpdate]) -> [UInt8] {
        FastPathLength.frame(header: 0x00, payload: updates.flatMap { $0.encode() })
    }

    /// Parses the updates of a fast-path output PDU (used by clients and tests).
    public static func parsePdu(_ frame: [UInt8]) throws -> [FastPathUpdate] {
        var reader = ByteReader(frame)
        _ = try reader.readUInt8()
        if try reader.readUInt8() & 0x80 != 0 { try reader.skip(1) }
        var updates: [FastPathUpdate] = []
        while reader.remaining >= 3 {
            let header = try reader.readUInt8()
            let size = Int(try reader.readUInt16LE())
            guard let code = FastPathUpdateCode(rawValue: header & 0x0F) else {
                try reader.skip(size)
                continue
            }
            updates.append(FastPathUpdate(code: code, data: try reader.readBytes(size)))
        }
        return updates
    }
}
