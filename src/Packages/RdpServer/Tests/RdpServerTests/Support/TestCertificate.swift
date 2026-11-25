import RdpServer

/// A certificate generated once for all tests (RSA key generation is slow).
enum TestCertificate {
    static let shared: TlsCertificate = {
        do {
            return try SelfSignedCertificateGenerator.generate(commonName: "localhost")
        } catch {
            fatalError("cannot generate test certificate: \(error)")
        }
    }()
}
