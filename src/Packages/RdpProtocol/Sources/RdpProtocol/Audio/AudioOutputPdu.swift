/// Audio output PDUs of the "rdpsnd" static virtual channel (MS-RDPEA 2.2).
public enum AudioOutputPdu: Sendable, Equatable {
    /// Server or Client Audio Formats and Version PDU.
    case formats(flags: UInt32, version: UInt16, formats: [AudioFormat])
    /// Training PDU (server) or Training Confirm PDU (client).
    case training(timestamp: UInt16, packSize: UInt16)
    case waveConfirm(timestamp: UInt16, blockNumber: UInt8)
    case qualityMode(UInt16)
    case close
    case other(messageType: UInt8)

    /// SNDPROLOG msgType values.
    public enum MessageType: UInt8, Sendable {
        case close = 0x01
        case wave = 0x02
        case setVolume = 0x03
        case setPitch = 0x04
        case waveConfirm = 0x05
        case training = 0x06
        case formats = 0x07
        case qualityMode = 0x0C
        case wave2 = 0x0D
    }

    /// Client flags of the Client Audio Formats and Version PDU.
    public static let clientAlive: UInt32 = 0x0000_0001
    public static let clientVolume: UInt32 = 0x0000_0002
    /// Protocol version announced by the server; 6 uses Wave Info and Wave PDUs, not Wave2.
    public static let serverVersion: UInt16 = 6

    public static func parse(_ bytes: [UInt8]) throws -> AudioOutputPdu {
        var reader = ByteReader(bytes)
        let type = try reader.readUInt8()
        try reader.skip(1)
        let bodySize = Int(try reader.readUInt16LE())
        var body = ByteReader(try reader.readBytes(min(bodySize, reader.remaining)))
        switch MessageType(rawValue: type) {
        case .formats:
            let flags = try body.readUInt32LE()
            try body.skip(4 + 4 + 2) // dwVolume, dwPitch, wDGramPort
            let count = Int(try body.readUInt16LE())
            try body.skip(1) // cLastBlockConfirmed
            let version = try body.readUInt16LE()
            try body.skip(1)
            var formats: [AudioFormat] = []
            for _ in 0..<count {
                formats.append(try AudioFormat.parse(&body))
            }
            return .formats(flags: flags, version: version, formats: formats)
        case .training:
            return .training(timestamp: try body.readUInt16LE(), packSize: try body.readUInt16LE())
        case .waveConfirm:
            return .waveConfirm(timestamp: try body.readUInt16LE(), blockNumber: try body.readUInt8())
        case .qualityMode:
            return .qualityMode(try body.readUInt16LE())
        case .close:
            return .close
        default:
            return .other(messageType: type)
        }
    }

    public func encode() -> [UInt8] {
        var body = ByteWriter()
        let type: MessageType
        switch self {
        case .formats(let flags, let version, let formats):
            type = .formats
            body.writeUInt32LE(flags)
            body.writeUInt32LE(0) // dwVolume
            body.writeUInt32LE(0) // dwPitch
            body.writeUInt16BE(0) // wDGramPort: no UDP
            body.writeUInt16LE(UInt16(formats.count))
            body.writeUInt8(0) // cLastBlockConfirmed
            body.writeUInt16LE(version)
            body.writeUInt8(0)
            for format in formats { format.encode(into: &body) }
        case .training(let timestamp, let packSize):
            type = .training
            body.writeUInt16LE(timestamp)
            body.writeUInt16LE(packSize)
        case .waveConfirm(let timestamp, let blockNumber):
            type = .waveConfirm
            body.writeUInt16LE(timestamp)
            body.writeUInt8(blockNumber)
            body.writeUInt8(0)
        case .qualityMode(let mode):
            type = .qualityMode
            body.writeUInt16LE(mode)
            body.writeUInt16LE(0)
        case .close:
            type = .close
        case .other(let messageType):
            return Self.header(type: messageType, bodySize: 0)
        }
        return Self.header(type: type.rawValue, bodySize: body.count) + body.bytes
    }

    /// Wave Info PDU followed by the Wave PDU carrying one block of audio (MS-RDPEA 2.2.3.3 and 2.2.3.4).
    /// They are sent as two separate channel messages.
    public static func wave(timestamp: UInt16, formatIndex: UInt16, blockNumber: UInt8, data: [UInt8]) -> (info: [UInt8], wave: [UInt8]) {
        precondition(data.count >= 4, "an audio block has at least 4 bytes")
        var info = ByteWriter(capacity: 16)
        info.writeBytes(header(type: MessageType.wave.rawValue, bodySize: 8 + data.count))
        info.writeUInt16LE(timestamp)
        info.writeUInt16LE(formatIndex)
        info.writeUInt8(blockNumber)
        info.writeZeros(3)
        info.writeBytes(data[0..<4])
        var wave = ByteWriter(capacity: data.count)
        wave.writeZeros(4)
        wave.writeBytes(data[4...])
        return (info.bytes, wave.bytes)
    }

    static func header(type: UInt8, bodySize: Int) -> [UInt8] {
        [type, 0, UInt8(truncatingIfNeeded: bodySize), UInt8(truncatingIfNeeded: bodySize >> 8)]
    }
}
