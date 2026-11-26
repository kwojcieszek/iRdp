import Crypto
import Foundation

/// Server side of CredSSP (MS-CSSP) with NTLM, raw or inside SPNEGO, bound to the TLS public key.
struct CredSspServer {
    static let logonFailure: UInt32 = 0xC000_006D
    static let maximumVersion = 6

    enum Phase { case negotiate, authenticate, credentials, done }

    private let publicKey: [UInt8]
    private let computerName: String
    private let ntHash: (String) -> [UInt8]?
    private var ntlm: NtlmServerContext
    private var phase = Phase.negotiate
    private var usesSpnego = false
    private var mechTypes: [UInt8] = []
    private var version = 2
    private var clientNonce: [UInt8]?

    /// `publicKey` is the subjectPublicKey of the TLS certificate; `ntHash` returns the NT hash of an account.
    init(publicKey: [UInt8], computerName: String, ntHash: @escaping (String) -> [UInt8]?, ntlm: NtlmServerContext = NtlmServerContext()) {
        self.publicKey = publicKey
        self.computerName = computerName
        self.ntHash = ntHash
        self.ntlm = ntlm
    }

    var authenticatedUserName: String { ntlm.userName }

    mutating func receive(_ bytes: [UInt8]) -> CredSspStep {
        do {
            return try handle(TsRequest.parse(bytes))
        } catch NlaError.logonFailure {
            phase = .done
            return .failed(reason: "wrong user name or password", response: version >= 3 ? TsRequest(version: version, errorCode: Self.logonFailure).encode() : nil)
        } catch {
            phase = .done
            return .failed(reason: "\(error)", response: version >= 3 ? TsRequest(version: version, errorCode: Self.logonFailure).encode() : nil)
        }
    }

    private mutating func handle(_ request: TsRequest) throws -> CredSspStep {
        version = min(max(request.version, 2), Self.maximumVersion)
        if let nonce = request.clientNonce { clientNonce = nonce }
        switch phase {
        case .negotiate:
            guard let token = request.negoToken else { throw NlaError.malformed("missing negotiation token") }
            var ntlmToken = token
            if SpnegoToken.isSpnego(token) {
                usesSpnego = true
                switch try SpnegoToken.parse(token) {
                case .initial(let types, let mechToken):
                    mechTypes = types
                    guard let mechToken, NtlmMessages.messageType(mechToken) == 1 else {
                        // Ask the client to continue with NTLM.
                        return .respond(TsRequest(version: version, negoToken: SpnegoToken.serverResponse(state: 1, includesMechanism: true, token: nil, mechListMIC: nil)).encode())
                    }
                    ntlmToken = mechToken
                case .response(let responseToken, _):
                    guard let responseToken else { throw NlaError.malformed("SPNEGO response") }
                    ntlmToken = responseToken
                }
            }
            let challenge = try ntlm.challenge(for: ntlmToken, computerName: computerName)
            phase = .authenticate
            let reply = usesSpnego ? SpnegoToken.serverResponse(state: 1, includesMechanism: true, token: challenge, mechListMIC: nil) : challenge
            return .respond(TsRequest(version: version, negoToken: reply).encode())
        case .authenticate:
            guard let token = request.negoToken else { throw NlaError.malformed("missing AUTHENTICATE") }
            var authenticate = token
            var clientMic: [UInt8]?
            if usesSpnego, case .response(let responseToken, let mic) = try SpnegoToken.parse(token) {
                guard let responseToken else { throw NlaError.malformed("SPNEGO response") }
                authenticate = responseToken
                clientMic = mic
            }
            try ntlm.authenticate(authenticate, ntHash: ntHash)
            if let clientMic, !mechTypes.isEmpty { try ntlm.verifySignature(clientMic, of: mechTypes) }
            guard let sealedKey = request.pubKeyAuth else { throw NlaError.malformed("missing pubKeyAuth") }
            let clientKey = try ntlm.unseal(sealedKey)
            let serverKey: [UInt8]
            if version >= 5, let clientNonce {
                guard clientKey == Self.binding("CredSSP Client-To-Server Binding Hash", nonce: clientNonce, publicKey: publicKey) else { throw NlaError.integrity("public key binding") }
                serverKey = Self.binding("CredSSP Server-To-Client Binding Hash", nonce: clientNonce, publicKey: publicKey)
            } else {
                guard clientKey == publicKey else { throw NlaError.integrity("public key") }
                serverKey = [publicKey[0] &+ 1] + publicKey.dropFirst()
            }
            let mic = usesSpnego && !mechTypes.isEmpty ? try ntlm.sign(mechTypes) : nil
            let negoToken = usesSpnego ? SpnegoToken.serverResponse(state: 0, includesMechanism: false, token: nil, mechListMIC: mic) : nil
            let pubKeyAuth = try ntlm.seal(serverKey)
            phase = .credentials
            return .respond(TsRequest(version: version, negoToken: negoToken, pubKeyAuth: pubKeyAuth).encode())
        case .credentials:
            guard let authInfo = request.authInfo else { throw NlaError.malformed("missing authInfo") }
            let credentials = try TsCredentials.parse(ntlm.unseal(authInfo))
            phase = .done
            return .completed(credentials)
        case .done:
            throw NlaError.malformed("unexpected CredSSP message")
        }
    }

    static func binding(_ magic: String, nonce: [UInt8], publicKey: [UInt8]) -> [UInt8] {
        Array(SHA256.hash(data: Array(magic.utf8) + [0] + nonce + publicKey))
    }
}
