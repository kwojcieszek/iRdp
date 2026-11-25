import Foundation

/// Loads the server certificate from a directory, creating a self-signed one on first use.
public struct TlsCertificateStore: Sendable {
    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    public var certificateURL: URL { directory.appendingPathComponent("certificate.pem") }
    public var privateKeyURL: URL { directory.appendingPathComponent("private-key.pem") }

    public func loadOrCreate(commonName: String) throws -> TlsCertificate {
        let fileManager = FileManager.default
        if let certificate = try? String(contentsOf: certificateURL, encoding: .utf8),
           let key = try? String(contentsOf: privateKeyURL, encoding: .utf8) {
            return TlsCertificate(certificatePEM: certificate, privateKeyPEM: key)
        }
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let generated = try SelfSignedCertificateGenerator.generate(commonName: commonName)
        try Data(generated.certificatePEM.utf8).write(to: certificateURL, options: .atomic)
        try Data(generated.privateKeyPEM.utf8).write(to: privateKeyURL, options: .atomic)
        try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: privateKeyURL.path)
        return generated
    }
}
