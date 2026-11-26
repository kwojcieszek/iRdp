import Foundation
import NIOSSL
import Testing
@testable import RdpServer

struct TlsCertificateTests {
    @Test func generatedCertificateLoadsIntoNioSsl() throws {
        let certificate = TestCertificate.shared
        #expect(certificate.certificatePEM.hasPrefix("-----BEGIN CERTIFICATE-----"))
        _ = try NIOSSLCertificate(bytes: Array(certificate.certificatePEM.utf8), format: .pem)
        _ = try NIOSSLPrivateKey(bytes: Array(certificate.privateKeyPEM.utf8), format: .pem)
    }

    @Test func fingerprintIsColonSeparatedSha256() throws {
        let fingerprint = try SelfSignedCertificateGenerator.fingerprint(ofCertificatePEM: TestCertificate.shared.certificatePEM)
        #expect(fingerprint.split(separator: ":").count == 32)
    }

    @Test func storeCreatesCertificateOnceAndReusesIt() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = TlsCertificateStore(directory: directory)
        let first = try store.loadOrCreate(commonName: "test")
        let second = try store.loadOrCreate(commonName: "other")
        #expect(first == second)
        let permissions = try FileManager.default.attributesOfItem(atPath: store.privateKeyURL.path)[.posixPermissions] as? Int
        #expect(permissions == 0o600)
    }
}
