import Crypto
import _CryptoExtras
import Foundation
import SwiftASN1
import X509

/// Generates a self-signed RSA certificate suitable for an RDP server.
public enum SelfSignedCertificateGenerator {
    public static func generate(commonName: String, validity: TimeInterval = 10 * 365 * 24 * 3600) throws -> TlsCertificate {
        let rsaKey = try _RSA.Signing.PrivateKey(keySize: .bits2048)
        let privateKey = Certificate.PrivateKey(rsaKey)
        let name = try DistinguishedName {
            CommonName(commonName)
            OrganizationName("iRdp")
        }
        let now = Date()
        let certificate = try Certificate(
            version: .v3,
            serialNumber: Certificate.SerialNumber(),
            publicKey: privateKey.publicKey,
            notValidBefore: now.addingTimeInterval(-3600),
            notValidAfter: now.addingTimeInterval(validity),
            issuer: name,
            subject: name,
            signatureAlgorithm: .sha256WithRSAEncryption,
            extensions: try Certificate.Extensions {
                Critical(BasicConstraints.notCertificateAuthority)
                Critical(KeyUsage(digitalSignature: true, keyEncipherment: true))
                try ExtendedKeyUsage([.serverAuth])
                SubjectAlternativeNames([.dnsName(commonName)])
            },
            issuerPrivateKey: privateKey
        )
        return TlsCertificate(certificatePEM: try certificate.serializeAsPEM().pemString, privateKeyPEM: rsaKey.pemRepresentation)
    }

    /// SHA-256 fingerprint of a PEM certificate, formatted as colon separated hex.
    public static func fingerprint(ofCertificatePEM pem: String) throws -> String {
        let certificate = try Certificate(pemEncoded: pem)
        var serializer = DER.Serializer()
        try serializer.serialize(certificate)
        let digest = SHA256.hash(data: serializer.serializedBytes)
        return digest.map { String(format: "%02X", $0) }.joined(separator: ":")
    }
}
