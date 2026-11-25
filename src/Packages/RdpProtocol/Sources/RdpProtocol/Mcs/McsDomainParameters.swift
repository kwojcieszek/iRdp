/// T.125 DomainParameters sequence.
public struct McsDomainParameters: Sendable, Equatable {
    public var maxChannelIds: Int
    public var maxUserIds: Int
    public var maxTokenIds: Int
    public var numberOfPriorities: Int
    public var minimumThroughput: Int
    public var maxHeight: Int
    public var maxMcsPduSize: Int
    public var protocolVersion: Int

    public init(maxChannelIds: Int, maxUserIds: Int, maxTokenIds: Int, numberOfPriorities: Int, minimumThroughput: Int, maxHeight: Int, maxMcsPduSize: Int, protocolVersion: Int) {
        self.maxChannelIds = maxChannelIds
        self.maxUserIds = maxUserIds
        self.maxTokenIds = maxTokenIds
        self.numberOfPriorities = numberOfPriorities
        self.minimumThroughput = minimumThroughput
        self.maxHeight = maxHeight
        self.maxMcsPduSize = maxMcsPduSize
        self.protocolVersion = protocolVersion
    }

    public static let serverDefault = McsDomainParameters(maxChannelIds: 34, maxUserIds: 3, maxTokenIds: 0, numberOfPriorities: 1, minimumThroughput: 0, maxHeight: 1, maxMcsPduSize: 65528, protocolVersion: 2)
    public static let clientTarget = McsDomainParameters(maxChannelIds: 34, maxUserIds: 2, maxTokenIds: 0, numberOfPriorities: 1, minimumThroughput: 0, maxHeight: 1, maxMcsPduSize: 65535, protocolVersion: 2)

    public func encode() -> [UInt8] {
        BerEncoder.sequence(
            BerEncoder.integer(maxChannelIds) + BerEncoder.integer(maxUserIds) + BerEncoder.integer(maxTokenIds)
                + BerEncoder.integer(numberOfPriorities) + BerEncoder.integer(minimumThroughput) + BerEncoder.integer(maxHeight)
                + BerEncoder.integer(maxMcsPduSize) + BerEncoder.integer(protocolVersion)
        )
    }

    public static func parse(_ ber: inout BerReader) throws -> McsDomainParameters {
        var inner = BerReader(ByteReader(try ber.readSequence()))
        return McsDomainParameters(
            maxChannelIds: try inner.readInteger(), maxUserIds: try inner.readInteger(), maxTokenIds: try inner.readInteger(),
            numberOfPriorities: try inner.readInteger(), minimumThroughput: try inner.readInteger(), maxHeight: try inner.readInteger(),
            maxMcsPduSize: try inner.readInteger(), protocolVersion: try inner.readInteger()
        )
    }
}
