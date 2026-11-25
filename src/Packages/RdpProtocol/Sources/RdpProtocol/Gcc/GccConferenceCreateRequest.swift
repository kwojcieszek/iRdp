/// GCC Conference Create Request (T.124) wrapped in the MCS Connect-Initial user data.
public enum GccConferenceCreateRequest {
    static let clientKey: [UInt8] = Array("Duca".utf8)

    /// Extracts the client data blocks following the "Duca" H.221 key.
    public static func parse(_ userData: [UInt8]) throws -> [DataBlock] {
        guard let keyIndex = userData.firstRange(of: clientKey)?.upperBound else {
            throw RdpProtocolError.invalidValue("missing GCC client key")
        }
        var reader = ByteReader(userData, offset: keyIndex)
        let length = try PerEncoding.readLength(&reader)
        return try DataBlock.parseAll(try reader.readBytes(length))
    }

    public static func encode(clientData: [UInt8]) -> [UInt8] {
        let body: [UInt8] = [0x00, 0x08, 0x00, 0x10, 0x00, 0x01, 0xC0, 0x00] + clientKey + PerEncoding.length(clientData.count) + clientData
        return [0x00, 0x05, 0x00, 0x14, 0x7C, 0x00, 0x01] + PerEncoding.length(body.count) + body
    }
}
