/// SPNEGO (RFC 4178) tokens carrying NTLM inside CredSSP.
enum SpnegoToken: Equatable {
    /// NegTokenInit: the DER of mechTypes (needed for mechListMIC) and the optimistic mechanism token.
    case initial(mechTypes: [UInt8], mechToken: [UInt8]?)
    /// NegTokenResp from the client.
    case response(responseToken: [UInt8]?, mechListMIC: [UInt8]?)

    static let ntlmOid: [UInt8] = [0x06, 0x0A, 0x2B, 0x06, 0x01, 0x04, 0x01, 0x82, 0x37, 0x02, 0x02, 0x0A]

    static func isSpnego(_ token: [UInt8]) -> Bool {
        token.first == 0x60 || token.first == 0xA1
    }

    static func parse(_ token: [UInt8]) throws -> SpnegoToken {
        let (root, _) = try DerNode.parse(token)
        switch root.tag {
        case 0x60:
            // [APPLICATION 0] { OID, [0] NegTokenInit }
            guard let wrapper = try root.child(tag: 0xA0), let initToken = try wrapper.children().first else { throw NlaError.malformed("NegTokenInit") }
            let mechTypes = try initToken.child(tag: 0xA0)?.children().first?.encoded ?? []
            let mechToken = try initToken.child(tag: 0xA2)?.children().first?.content
            return .initial(mechTypes: mechTypes, mechToken: mechToken)
        case 0xA1:
            guard let response = try root.children().first else { throw NlaError.malformed("NegTokenResp") }
            let token = try response.child(tag: 0xA2)?.children().first?.content
            let mic = try response.child(tag: 0xA3)?.children().first?.content
            return .response(responseToken: token, mechListMIC: mic)
        default:
            throw NlaError.malformed("SPNEGO token")
        }
    }

    /// Server NegTokenResp: negState (0 completed, 1 incomplete), optional NTLM mechanism, token and MIC.
    static func serverResponse(state: UInt8, includesMechanism: Bool, token: [UInt8]?, mechListMIC: [UInt8]?) -> [UInt8] {
        var content = Der.context(0, Der.enumerated(state))
        if includesMechanism { content += Der.context(1, ntlmOid) }
        if let token { content += Der.context(2, Der.octetString(token)) }
        if let mechListMIC { content += Der.context(3, Der.octetString(mechListMIC)) }
        return Der.tlv(0xA1, Der.sequence(content))
    }
}
