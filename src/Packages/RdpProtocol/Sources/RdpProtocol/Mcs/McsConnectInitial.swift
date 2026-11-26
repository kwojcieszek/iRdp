/// MCS Connect-Initial PDU (BER, application tag 101) carrying the GCC Conference Create Request.
public struct McsConnectInitial: Sendable, Equatable {
    public static let applicationTag: UInt8 = 0x65

    public var targetParameters: McsDomainParameters
    public var userData: [UInt8]

    public init(targetParameters: McsDomainParameters = .clientTarget, userData: [UInt8]) {
        self.targetParameters = targetParameters
        self.userData = userData
    }

    /// Parses the MCS payload (after the X.224 data header).
    public static func parse(_ payload: [UInt8]) throws -> McsConnectInitial {
        var ber = BerReader(ByteReader(payload))
        _ = try ber.readApplicationTag(applicationTag)
        _ = try ber.readOctetString()
        _ = try ber.readOctetString()
        _ = try ber.readBoolean()
        let target = try McsDomainParameters.parse(&ber)
        _ = try McsDomainParameters.parse(&ber)
        _ = try McsDomainParameters.parse(&ber)
        return McsConnectInitial(targetParameters: target, userData: try ber.readOctetString())
    }

    public func encode() -> [UInt8] {
        let minimum = McsDomainParameters(maxChannelIds: 1, maxUserIds: 1, maxTokenIds: 1, numberOfPriorities: 1, minimumThroughput: 0, maxHeight: 1, maxMcsPduSize: 1056, protocolVersion: 2)
        let maximum = McsDomainParameters(maxChannelIds: 65535, maxUserIds: 64535, maxTokenIds: 65535, numberOfPriorities: 1, minimumThroughput: 0, maxHeight: 1, maxMcsPduSize: 65535, protocolVersion: 2)
        let content = BerEncoder.octetString([1]) + BerEncoder.octetString([1]) + BerEncoder.boolean(true)
            + targetParameters.encode() + minimum.encode() + maximum.encode() + BerEncoder.octetString(userData)
        return BerEncoder.tagged(BerEncoder.applicationTag(Self.applicationTag), content)
    }
}
