/// Parsed NTLM AUTHENTICATE_MESSAGE.
struct NtlmAuthenticateMessage {
    let ntChallengeResponse: [UInt8]
    let domain: String
    let userName: String
    let encryptedRandomSessionKey: [UInt8]
    let flags: UInt32
    let mic: [UInt8]?
    let raw: [UInt8]

    static func parse(_ message: [UInt8]) throws -> NtlmAuthenticateMessage {
        guard NtlmMessages.messageType(message) == 3, message.count >= 64 else { throw NlaError.malformed("AUTHENTICATE") }
        func u16(_ o: Int) -> Int { Int(message[o]) | Int(message[o + 1]) << 8 }
        func u32(_ o: Int) -> UInt32 { UInt32(message[o]) | UInt32(message[o + 1]) << 8 | UInt32(message[o + 2]) << 16 | UInt32(message[o + 3]) << 24 }
        func field(_ o: Int) throws -> [UInt8] {
            let length = u16(o)
            let offset = Int(u32(o + 4))
            guard offset + length <= message.count else { throw NlaError.malformed("AUTHENTICATE field") }
            return Array(message[offset..<offset + length])
        }
        func string(_ bytes: [UInt8]) -> String {
            var units: [UInt16] = []
            var index = 0
            while index + 1 < bytes.count { units.append(UInt16(bytes[index]) | UInt16(bytes[index + 1]) << 8); index += 2 }
            return String(decoding: units, as: UTF16.self)
        }
        let flags = u32(60)
        let ntResponse = try field(20)
        // The MIC follows the version field when the payload starts after it (offset 88).
        let payloadStart = [12, 20, 28, 36, 44, 52].map { Int(u32($0 + 4)) }.filter { $0 > 0 }.min() ?? 64
        let mic: [UInt8]? = payloadStart >= 88 && message.count >= 88 ? Array(message[72..<88]) : nil
        return NtlmAuthenticateMessage(
            ntChallengeResponse: ntResponse, domain: string(try field(28)), userName: string(try field(36)),
            encryptedRandomSessionKey: try field(52), flags: flags, mic: mic, raw: message
        )
    }
}
