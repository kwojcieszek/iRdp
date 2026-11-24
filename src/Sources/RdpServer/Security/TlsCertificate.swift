/// A PEM encoded certificate and private key used for the TLS security layer.
public struct TlsCertificate: Sendable, Equatable {
    public var certificatePEM: String
    public var privateKeyPEM: String

    public init(certificatePEM: String, privateKeyPEM: String) {
        self.certificatePEM = certificatePEM
        self.privateKeyPEM = privateKeyPEM
    }
}
