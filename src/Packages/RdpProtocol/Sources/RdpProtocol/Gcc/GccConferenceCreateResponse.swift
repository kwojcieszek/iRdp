/// GCC Conference Create Response (T.124) wrapped in the MCS Connect-Response user data.
public enum GccConferenceCreateResponse {
    static let serverKey: [UInt8] = Array("McDn".utf8)

    public static func encode(serverData: [UInt8]) -> [UInt8] {
        let body: [UInt8] = [0x14, 0x76, 0x0A, 0x01, 0x01, 0x00, 0x01, 0xC0, 0x00] + serverKey + PerEncoding.length(serverData.count) + serverData
        return [0x00, 0x05, 0x00, 0x14, 0x7C, 0x00, 0x01] + PerEncoding.length(body.count) + body
    }

    public static func parse(_ userData: [UInt8]) throws -> [DataBlock] {
        guard let keyIndex = userData.firstRange(of: serverKey)?.upperBound else {
            throw RdpProtocolError.invalidValue("missing GCC server key")
        }
        var reader = ByteReader(userData, offset: keyIndex)
        let length = try PerEncoding.readLength(&reader)
        return try DataBlock.parseAll(try reader.readBytes(length))
    }
}
