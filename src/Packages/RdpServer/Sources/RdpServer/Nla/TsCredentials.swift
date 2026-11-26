/// CredSSP TSCredentials with TSPasswordCreds (MS-CSSP 2.2.1.2).
struct TsCredentials: Equatable {
    var domain: String
    var userName: String
    var password: String

    static func parse(_ bytes: [UInt8]) throws -> TsCredentials {
        let (root, _) = try DerNode.parse(bytes)
        guard let type = try root.child(tag: 0xA0)?.children().first, type.integerValue == 1 else { throw NlaError.unsupported("credential type") }
        guard let wrapped = try root.child(tag: 0xA1)?.children().first else { throw NlaError.malformed("TSCredentials") }
        let (passwordCreds, _) = try DerNode.parse(wrapped.content)
        func string(_ tag: UInt8) throws -> String {
            let bytes = try passwordCreds.child(tag: tag)?.children().first?.content ?? []
            var units: [UInt16] = []
            var index = 0
            while index + 1 < bytes.count { units.append(UInt16(bytes[index]) | UInt16(bytes[index + 1]) << 8); index += 2 }
            return String(decoding: units, as: UTF16.self)
        }
        return TsCredentials(domain: try string(0xA0), userName: try string(0xA1), password: try string(0xA2))
    }

    func encode() -> [UInt8] {
        func utf16(_ text: String) -> [UInt8] { text.utf16.flatMap { [UInt8(truncatingIfNeeded: $0), UInt8(truncatingIfNeeded: $0 >> 8)] } }
        let passwordCreds = Der.sequence(Der.context(0, Der.octetString(utf16(domain))) + Der.context(1, Der.octetString(utf16(userName))) + Der.context(2, Der.octetString(utf16(password))))
        return Der.sequence(Der.context(0, Der.integer(1)) + Der.context(1, Der.octetString(passwordCreds)))
    }
}
