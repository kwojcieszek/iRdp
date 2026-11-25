/// MCS Connect-Response PDU (BER, application tag 102) carrying the GCC Conference Create Response.
public struct McsConnectResponse: Sendable, Equatable {
    public static let applicationTag: UInt8 = 0x66

    public var result: UInt8
    public var domainParameters: McsDomainParameters
    public var userData: [UInt8]

    public init(result: UInt8 = 0, domainParameters: McsDomainParameters = .serverDefault, userData: [UInt8]) {
        self.result = result
        self.domainParameters = domainParameters
        self.userData = userData
    }

    public func encode() -> [UInt8] {
        let content = BerEncoder.enumerated(result) + BerEncoder.integer(0) + domainParameters.encode() + BerEncoder.octetString(userData)
        return BerEncoder.tagged(BerEncoder.applicationTag(Self.applicationTag), content)
    }

    public static func parse(_ payload: [UInt8]) throws -> McsConnectResponse {
        var ber = BerReader(ByteReader(payload))
        _ = try ber.readApplicationTag(applicationTag)
        let result = try ber.readEnumerated()
        _ = try ber.readInteger()
        let parameters = try McsDomainParameters.parse(&ber)
        return McsConnectResponse(result: result, domainParameters: parameters, userData: try ber.readOctetString())
    }
}
