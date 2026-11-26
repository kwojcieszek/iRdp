import Crypto
import Foundation

/// Server side of NTLMv2 with extended session security: builds the challenge, verifies the response against the
/// account's NT hash and provides message sealing/signing for CredSSP.
struct NtlmServerContext {
    private(set) var negotiateMessage: [UInt8] = []
    private(set) var challengeMessage: [UInt8] = []
    private(set) var flags: UInt32 = 0
    private let serverChallenge: [UInt8]
    private var clientSealing: Rc4?
    private var serverSealing: Rc4?
    private var clientSigningKey: [UInt8] = []
    private var serverSigningKey: [UInt8] = []
    private var clientSequence: UInt32 = 0
    private var serverSequence: UInt32 = 0
    private(set) var userName = ""
    private(set) var domain = ""

    init(serverChallenge: [UInt8] = (0..<8).map { _ in UInt8.random(in: 0...255) }) {
        self.serverChallenge = serverChallenge
    }

    static func hmacMd5(_ key: [UInt8], _ data: [UInt8]) -> [UInt8] {
        Array(HMAC<Insecure.MD5>.authenticationCode(for: data, using: SymmetricKey(data: key)))
    }

    static func md5(_ data: [UInt8]) -> [UInt8] {
        Array(Insecure.MD5.hash(data: data))
    }

    mutating func challenge(for negotiate: [UInt8], computerName: String, now: Date = Date()) throws -> [UInt8] {
        guard NtlmMessages.messageType(negotiate) == 1 else { throw NlaError.malformed("NEGOTIATE") }
        negotiateMessage = negotiate
        flags = NtlmFlags.serverFlags(for: NtlmMessages.negotiateFlags(negotiate))
        let fileTime = UInt64((now.timeIntervalSince1970 + 11_644_473_600) * 10_000_000)
        challengeMessage = NtlmMessages.challenge(flags: flags, serverChallenge: serverChallenge, computerName: computerName, timestamp: fileTime)
        return challengeMessage
    }

    /// Verifies AUTHENTICATE with the NT hash provided for its user and sets up the session keys.
    mutating func authenticate(_ message: [UInt8], ntHash: (String) -> [UInt8]?) throws {
        let authenticate = try NtlmAuthenticateMessage.parse(message)
        userName = authenticate.userName
        domain = authenticate.domain
        guard authenticate.ntChallengeResponse.count > 24, let hash = ntHash(authenticate.userName) else { throw NlaError.logonFailure }
        let ntProof = Array(authenticate.ntChallengeResponse[0..<16])
        let blob = Array(authenticate.ntChallengeResponse[16...])
        let identity = NtlmMessages.utf16(authenticate.userName.uppercased() + authenticate.domain)
        let responseKey = Self.hmacMd5(hash, identity)
        guard Self.hmacMd5(responseKey, serverChallenge + blob) == ntProof else { throw NlaError.logonFailure }
        let keyExchangeKey = Self.hmacMd5(responseKey, ntProof)
        var exportedSessionKey = keyExchangeKey
        if flags & NtlmFlags.keyExchange != 0, authenticate.encryptedRandomSessionKey.count == 16 {
            var rc4 = Rc4(key: keyExchangeKey)
            exportedSessionKey = rc4.process(authenticate.encryptedRandomSessionKey)
        }
        if let mic = authenticate.mic, mic.contains(where: { $0 != 0 }) {
            var zeroed = authenticate.raw
            for index in 72..<88 { zeroed[index] = 0 }
            guard Self.hmacMd5(exportedSessionKey, negotiateMessage + challengeMessage + zeroed) == mic else { throw NlaError.integrity("NTLM MIC") }
        }
        func key(_ magic: String) -> [UInt8] { Self.md5(exportedSessionKey + Array(magic.utf8) + [0]) }
        clientSigningKey = key("session key to client-to-server signing key magic constant")
        serverSigningKey = key("session key to server-to-client signing key magic constant")
        clientSealing = Rc4(key: key("session key to client-to-server sealing key magic constant"))
        serverSealing = Rc4(key: key("session key to server-to-client sealing key magic constant"))
    }

    private static func sequenceBytes(_ value: UInt32) -> [UInt8] {
        (0..<4).map { UInt8(truncatingIfNeeded: value >> UInt32($0 * 8)) }
    }

    /// Decrypts and verifies a message sealed by the client (signature of 16 bytes followed by the data).
    mutating func unseal(_ sealed: [UInt8]) throws -> [UInt8] {
        guard sealed.count >= 16, var rc4 = clientSealing else { throw NlaError.malformed("sealed message") }
        let data = rc4.process(Array(sealed[16...]))
        let checksum = rc4.process(Array(Self.hmacMd5(clientSigningKey, Self.sequenceBytes(clientSequence) + data)[0..<8]))
        clientSealing = rc4
        guard Array(sealed[4..<12]) == checksum, Array(sealed[12..<16]) == Self.sequenceBytes(clientSequence) else { throw NlaError.integrity("sealed message") }
        clientSequence += 1
        return data
    }

    /// Verifies a client signature (e.g. the SPNEGO mechListMIC).
    mutating func verifySignature(_ signature: [UInt8], of data: [UInt8]) throws {
        guard signature.count == 16, var rc4 = clientSealing else { throw NlaError.malformed("signature") }
        let checksum = rc4.process(Array(Self.hmacMd5(clientSigningKey, Self.sequenceBytes(clientSequence) + data)[0..<8]))
        clientSealing = rc4
        guard Array(signature[4..<12]) == checksum else { throw NlaError.integrity("mechListMIC") }
        clientSequence += 1
    }

    mutating func seal(_ data: [UInt8]) throws -> [UInt8] {
        guard var rc4 = serverSealing else { throw NlaError.malformed("sealing state") }
        let encrypted = rc4.process(data)
        let checksum = rc4.process(Array(Self.hmacMd5(serverSigningKey, Self.sequenceBytes(serverSequence) + data)[0..<8]))
        serverSealing = rc4
        let signature = [1, 0, 0, 0] + checksum + Self.sequenceBytes(serverSequence)
        serverSequence += 1
        return signature + encrypted
    }

    mutating func sign(_ data: [UInt8]) throws -> [UInt8] {
        guard var rc4 = serverSealing else { throw NlaError.malformed("sealing state") }
        let checksum = rc4.process(Array(Self.hmacMd5(serverSigningKey, Self.sequenceBytes(serverSequence) + data)[0..<8]))
        serverSealing = rc4
        let signature = [1, 0, 0, 0] + checksum + Self.sequenceBytes(serverSequence)
        serverSequence += 1
        return signature
    }
}
