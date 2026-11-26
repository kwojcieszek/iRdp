import Foundation

/// NTLM CHALLENGE and AUTHENTICATE messages (MS-NLMP 2.2.1).
enum NtlmMessages {
    static let signature: [UInt8] = Array("NTLMSSP\0".utf8)

    static func utf16(_ text: String) -> [UInt8] {
        text.utf16.flatMap { [UInt8(truncatingIfNeeded: $0), UInt8(truncatingIfNeeded: $0 >> 8)] }
    }

    static func messageType(_ message: [UInt8]) -> UInt32? {
        guard message.count >= 12, Array(message[0..<8]) == signature else { return nil }
        return UInt32(message[8]) | UInt32(message[9]) << 8 | UInt32(message[10]) << 16 | UInt32(message[11]) << 24
    }

    static func negotiateFlags(_ negotiate: [UInt8]) -> UInt32 {
        guard negotiate.count >= 16 else { return 0 }
        return UInt32(negotiate[12]) | UInt32(negotiate[13]) << 8 | UInt32(negotiate[14]) << 16 | UInt32(negotiate[15]) << 24
    }

    /// Builds CHALLENGE_MESSAGE with target information (names and timestamp).
    static func challenge(flags: UInt32, serverChallenge: [UInt8], computerName: String, timestamp: UInt64) -> [UInt8] {
        let targetName = utf16(computerName)
        var targetInfo: [UInt8] = []
        func avPair(_ id: UInt16, _ value: [UInt8]) {
            targetInfo += [UInt8(truncatingIfNeeded: id), UInt8(id >> 8), UInt8(truncatingIfNeeded: value.count), UInt8(value.count >> 8)] + value
        }
        avPair(2, targetName)
        avPair(1, targetName)
        avPair(4, targetName)
        avPair(3, targetName)
        avPair(7, (0..<8).map { UInt8(truncatingIfNeeded: timestamp >> UInt64($0 * 8)) })
        avPair(0, [])
        let headerLength = 56
        var message = signature
        func u16(_ v: Int) -> [UInt8] { [UInt8(truncatingIfNeeded: v), UInt8(truncatingIfNeeded: v >> 8)] }
        func u32(_ v: UInt32) -> [UInt8] { (0..<4).map { UInt8(truncatingIfNeeded: v >> UInt32($0 * 8)) } }
        message += u32(2)
        message += u16(targetName.count) + u16(targetName.count) + u32(UInt32(headerLength))
        message += u32(flags)
        message += serverChallenge
        message += [UInt8](repeating: 0, count: 8)
        message += u16(targetInfo.count) + u16(targetInfo.count) + u32(UInt32(headerLength + targetName.count))
        message += [10, 0, 0x63, 0x45, 0, 0, 0, 0x0F] // version 10.0.17763, NTLM revision 15
        message += targetName + targetInfo
        return message
    }
}
