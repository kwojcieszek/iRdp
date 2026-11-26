import SwiftASN1
import X509

/// Extracts the subjectPublicKey (contents of the BIT STRING) of a PEM certificate, which CredSSP binds to.
enum SubjectPublicKey {
    static func of(certificatePEM pem: String) throws -> [UInt8] {
        let certificate = try Certificate(pemEncoded: pem)
        var serializer = DER.Serializer()
        try serializer.serialize(certificate)
        let (root, _) = try DerNode.parse(serializer.serializedBytes)
        guard let tbs = try root.children().first else { throw NlaError.malformed("certificate") }
        let fields = try tbs.children()
        let index = fields.first?.tag == 0xA0 ? 6 : 5
        guard fields.count > index else { throw NlaError.malformed("certificate fields") }
        guard let bitString = try fields[index].children().last, bitString.tag == 0x03, bitString.content.count > 1 else { throw NlaError.malformed("subjectPublicKey") }
        return Array(bitString.content.dropFirst())
    }
}
