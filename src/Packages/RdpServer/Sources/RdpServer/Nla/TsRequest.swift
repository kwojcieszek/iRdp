/// CredSSP TSRequest (MS-CSSP 2.2.1).
struct TsRequest: Equatable {
    var version: Int
    var negoToken: [UInt8]?
    var authInfo: [UInt8]?
    var pubKeyAuth: [UInt8]?
    var errorCode: UInt32?
    var clientNonce: [UInt8]?

    init(version: Int, negoToken: [UInt8]? = nil, authInfo: [UInt8]? = nil, pubKeyAuth: [UInt8]? = nil, errorCode: UInt32? = nil, clientNonce: [UInt8]? = nil) {
        self.version = version
        self.negoToken = negoToken
        self.authInfo = authInfo
        self.pubKeyAuth = pubKeyAuth
        self.errorCode = errorCode
        self.clientNonce = clientNonce
    }

    static func parse(_ bytes: [UInt8]) throws -> TsRequest {
        let (root, _) = try DerNode.parse(bytes)
        guard root.tag == 0x30 else { throw NlaError.malformed("TSRequest") }
        var request = TsRequest(version: 0)
        for field in try root.children() {
            let inner = try field.children().first
            switch field.tag {
            case 0xA0: request.version = inner?.integerValue ?? 0
            case 0xA1:
                // NegoData: SEQUENCE OF SEQUENCE { [0] OCTET STRING }
                if let item = try inner?.children().first, let token = try item.child(tag: 0xA0)?.children().first {
                    request.negoToken = token.content
                }
            case 0xA2: request.authInfo = inner?.content
            case 0xA3: request.pubKeyAuth = inner?.content
            case 0xA4: request.errorCode = inner.map { UInt32(truncatingIfNeeded: $0.integerValue) }
            case 0xA5: request.clientNonce = inner?.content
            default: break
            }
        }
        return request
    }

    func encode() -> [UInt8] {
        var content = Der.context(0, Der.integer(version))
        if let negoToken {
            content += Der.context(1, Der.sequence(Der.sequence(Der.context(0, Der.octetString(negoToken)))))
        }
        if let authInfo { content += Der.context(2, Der.octetString(authInfo)) }
        if let pubKeyAuth { content += Der.context(3, Der.octetString(pubKeyAuth)) }
        if let errorCode { content += Der.context(4, Der.integer(Int(errorCode))) }
        if let clientNonce { content += Der.context(5, Der.octetString(clientNonce)) }
        return Der.sequence(content)
    }
}
