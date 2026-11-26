/// A decoded share control PDU (and, for data PDUs, its share data header).
public struct SharePdu: Sendable, Equatable {
    public var type: ShareControlPduType
    public var source: UInt16
    public var dataType: ShareDataPduType?
    public var shareId: UInt32
    /// Body following the share control header (control PDUs) or the share data header (data PDUs).
    public var body: [UInt8]

    public init(type: ShareControlPduType, source: UInt16, dataType: ShareDataPduType? = nil, shareId: UInt32 = 0, body: [UInt8]) {
        self.type = type
        self.source = source
        self.dataType = dataType
        self.shareId = shareId
        self.body = body
    }

    public static let protocolVersion: UInt16 = 0x0010

    /// Parses one or more concatenated share PDUs from MCS channel data. Flow PDUs are skipped.
    public static func parseAll(_ data: [UInt8]) throws -> [SharePdu] {
        var reader = ByteReader(data)
        var pdus: [SharePdu] = []
        while reader.remaining >= 4 {
            let start = reader.offset
            let totalLength = Int(try reader.readUInt16LE())
            if totalLength == 0x8000 {
                try reader.skip(min(4, reader.remaining))
                continue
            }
            guard totalLength >= 6, start + totalLength <= data.count else {
                throw RdpProtocolError.invalidValue("share control length \(totalLength)")
            }
            let rawType = try reader.readUInt16LE() & 0x000F
            let source = try reader.readUInt16LE()
            let end = start + totalLength
            guard let type = ShareControlPduType(rawValue: rawType) else {
                try reader.skip(end - reader.offset)
                continue
            }
            if type == .data {
                let shareId = try reader.readUInt32LE()
                try reader.skip(4)
                let rawDataType = try reader.readUInt8()
                try reader.skip(3)
                let body = try reader.readBytes(end - reader.offset)
                if let dataType = ShareDataPduType(rawValue: rawDataType) {
                    pdus.append(SharePdu(type: type, source: source, dataType: dataType, shareId: shareId, body: body))
                }
            } else {
                pdus.append(SharePdu(type: type, source: source, body: try reader.readBytes(end - reader.offset)))
            }
        }
        return pdus
    }

    /// Encodes a share control PDU with the given body.
    public static func encodeControl(type: ShareControlPduType, source: UInt16, body: [UInt8]) -> [UInt8] {
        var writer = ByteWriter(capacity: body.count + 6)
        writer.writeUInt16LE(UInt16(body.count + 6))
        writer.writeUInt16LE(type.rawValue | protocolVersion)
        writer.writeUInt16LE(source)
        writer.writeBytes(body)
        return writer.bytes
    }

    /// Encodes a share data PDU (share control header + share data header + body).
    public static func encodeData(type: ShareDataPduType, shareId: UInt32, source: UInt16, body: [UInt8]) -> [UInt8] {
        var writer = ByteWriter(capacity: body.count + 18)
        writer.writeUInt16LE(UInt16(body.count + 18))
        writer.writeUInt16LE(ShareControlPduType.data.rawValue | protocolVersion)
        writer.writeUInt16LE(source)
        writer.writeUInt32LE(shareId)
        writer.writeUInt8(0)
        writer.writeUInt8(1)
        writer.writeUInt16LE(UInt16(body.count + 4))
        writer.writeUInt8(type.rawValue)
        writer.writeUInt8(0)
        writer.writeUInt16LE(0)
        writer.writeBytes(body)
        return writer.bytes
    }
}
