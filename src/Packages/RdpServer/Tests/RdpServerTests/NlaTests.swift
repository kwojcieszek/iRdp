import RdpProtocol
import Testing
@testable import RdpServer

struct NlaTests {
    private func hex(_ bytes: [UInt8]) -> String { bytes.map { String(format: "%02x", $0) }.joined() }

    @Test func md4MatchesRfc1320() {
        #expect(hex(Md4.hash([])) == "31d6cfe0d16ae931b73c59d7e0c089c0")
        #expect(hex(Md4.hash(Array("abc".utf8))) == "a448017aaf21d8525fc10ae87aa6729d")
        #expect(hex(Md4.hash(Array("12345678901234567890123456789012345678901234567890123456789012345678901234567890".utf8))) == "e33b4ddc9c38f2199c3e7b164fcc0536")
    }

    @Test func ntHashMatchesKnownValue() {
        #expect(hex(NtHash.of(password: "Password")) == "a4f49c406510bdcab6824ee7c30fd852")
    }

    @Test func rc4MatchesKnownStream() {
        var rc4 = Rc4(key: Array("Key".utf8))
        #expect(hex(rc4.process(Array("Plaintext".utf8))) == "bbf316e8d940af0ad3")
    }

    @Test func roundTripsTsRequestAndCredentials() throws {
        let request = TsRequest(version: 6, negoToken: [1, 2, 3], authInfo: [4], pubKeyAuth: [5, 6], errorCode: 0xC000_006D, clientNonce: [7, 8])
        #expect(try TsRequest.parse(request.encode()) == request)
        let credentials = TsCredentials(domain: "MAC", userName: "kamil", password: "ząb")
        #expect(try TsCredentials.parse(credentials.encode()) == credentials)
    }

    @Test func measuresDerElements() {
        #expect(DerNode.elementLength(of: [0x30, 0x03, 1, 2, 3]) == 5)
        #expect(DerNode.elementLength(of: [0x30, 0x82, 0x01, 0x00]) == 260)
        #expect(DerNode.elementLength(of: [0x30]) == nil)
    }

    @Test func respondsToNegotiateWithChallengeAndRejectsWrongPassword() throws {
        var server = CredSspServer(publicKey: [1, 2, 3], computerName: "MAC", ntHash: { _ in NtHash.of(password: "secret") })
        // NTLM NEGOTIATE with unicode, NTLM, extended session security, sign, seal and key exchange.
        var negotiate = Array("NTLMSSP\0".utf8) + [1, 0, 0, 0]
        let flags: UInt32 = NtlmFlags.unicode | NtlmFlags.ntlm | NtlmFlags.extendedSessionSecurity | NtlmFlags.sign | NtlmFlags.seal | NtlmFlags.keyExchange
        negotiate += (0..<4).map { UInt8(truncatingIfNeeded: flags >> UInt32($0 * 8)) } + [UInt8](repeating: 0, count: 16)
        guard case .respond(let reply) = server.receive(TsRequest(version: 6, negoToken: negotiate).encode()) else { Issue.record("no challenge"); return }
        let challenge = try #require(try TsRequest.parse(reply).negoToken)
        #expect(NtlmMessages.messageType(challenge) == 2)

        // An AUTHENTICATE with a made-up response must fail with STATUS_LOGON_FAILURE.
        var authenticate = Array("NTLMSSP\0".utf8) + [3, 0, 0, 0] + [UInt8](repeating: 0, count: 52)
        let response = [UInt8](repeating: 0xAB, count: 48)
        let offset = authenticate.count
        authenticate[20] = 48; authenticate[22] = 48; authenticate[24] = UInt8(offset)
        authenticate += response
        guard case .failed(_, let failure) = server.receive(TsRequest(version: 6, negoToken: authenticate, pubKeyAuth: [0]).encode()) else { Issue.record("not rejected"); return }
        #expect(try TsRequest.parse(#require(failure)).errorCode == CredSspServer.logonFailure)
    }

    @Test func netBiosNameIsShortAndUppercase() {
        #expect(RdpConnectionHandler.netBiosName("Mac-Studio.local") == "MAC-STUDIO")
        #expect(RdpConnectionHandler.netBiosName("a very long computer name here").count <= 15)
    }
}

/// Network level authentication on the wire: clients that cannot do NLA are refused.
@Suite(.serialized, .timeLimit(.minutes(1)))
struct NlaNegotiationTests {
    @Test func clientWithoutNlaIsRefused() async throws {
        let environment = RdpSessionEnvironment(
            credentialValidator: FixedCredentialValidator(userName: "kamil", password: "secret"),
            makeSessionResources: { RdpSessionResources(frameSource: TestPatternFrameSource(), inputSink: nil) }
        )
        let server = RdpServer(configuration: RdpServerConfiguration(host: "127.0.0.1", port: 0, certificate: TestCertificate.shared, requiresNetworkLevelAuthentication: true), environment: environment)
        let port = try await server.start()
        defer { Task { await server.stop() } }
        let (client, confirm) = try await RdpTestClient.connect(port: port, requestedProtocols: [.tls])
        #expect(confirm.outcome == .failure(.hybridRequiredByServer))
        await client.close()
        let (nlaClient, nlaConfirm) = try await RdpTestClient.connect(port: port, requestedProtocols: [.tls, .credSsp])
        #expect(nlaConfirm.outcome == .selected(.credSsp, flags: X224ConnectionConfirm.extendedClientDataSupported | X224ConnectionConfirm.dynamicVirtualChannelGraphicsSupported))
        await nlaClient.close()
    }

    @Test func extractsCertificatePublicKey() throws {
        let key = try SubjectPublicKey.of(certificatePEM: TestCertificate.shared.certificatePEM)
        #expect(key.first == 0x30, "an RSAPublicKey sequence")
        #expect(key.count > 260)
    }
}
