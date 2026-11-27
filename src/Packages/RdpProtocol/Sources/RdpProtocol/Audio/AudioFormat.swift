/// AUDIO_FORMAT structure (MS-RDPEA 2.2.2.1.1), a WAVEFORMATEX without the size field of the extra data.
public struct AudioFormat: Sendable, Equatable {
    public static let pcmTag: UInt16 = 0x0001

    public var formatTag: UInt16
    public var channels: UInt16
    public var samplesPerSecond: UInt32
    public var averageBytesPerSecond: UInt32
    public var blockAlign: UInt16
    public var bitsPerSample: UInt16
    public var extraData: [UInt8]

    public init(formatTag: UInt16, channels: UInt16, samplesPerSecond: UInt32, averageBytesPerSecond: UInt32, blockAlign: UInt16, bitsPerSample: UInt16, extraData: [UInt8] = []) {
        self.formatTag = formatTag
        self.channels = channels
        self.samplesPerSecond = samplesPerSecond
        self.averageBytesPerSecond = averageBytesPerSecond
        self.blockAlign = blockAlign
        self.bitsPerSample = bitsPerSample
        self.extraData = extraData
    }

    /// Uncompressed little endian PCM.
    public static func pcm(samplesPerSecond: UInt32, channels: UInt16, bitsPerSample: UInt16 = 16) -> AudioFormat {
        let blockAlign = channels * bitsPerSample / 8
        return AudioFormat(formatTag: pcmTag, channels: channels, samplesPerSecond: samplesPerSecond, averageBytesPerSecond: samplesPerSecond * UInt32(blockAlign), blockAlign: blockAlign, bitsPerSample: bitsPerSample)
    }

    public var isPcm: Bool { formatTag == Self.pcmTag }

    public static func parse(_ reader: inout ByteReader) throws -> AudioFormat {
        let tag = try reader.readUInt16LE()
        let channels = try reader.readUInt16LE()
        let rate = try reader.readUInt32LE()
        let average = try reader.readUInt32LE()
        let align = try reader.readUInt16LE()
        let bits = try reader.readUInt16LE()
        let extra = try reader.readBytes(Int(try reader.readUInt16LE()))
        return AudioFormat(formatTag: tag, channels: channels, samplesPerSecond: rate, averageBytesPerSecond: average, blockAlign: align, bitsPerSample: bits, extraData: extra)
    }

    public func encode(into writer: inout ByteWriter) {
        writer.writeUInt16LE(formatTag)
        writer.writeUInt16LE(channels)
        writer.writeUInt32LE(samplesPerSecond)
        writer.writeUInt32LE(averageBytesPerSecond)
        writer.writeUInt16LE(blockAlign)
        writer.writeUInt16LE(bitsPerSample)
        writer.writeUInt16LE(UInt16(extraData.count))
        writer.writeBytes(extraData)
    }
}
