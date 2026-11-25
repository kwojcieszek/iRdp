import CommonCrypto
import Foundation
import Security

/// Hashes and verifies passwords with PBKDF2-SHA256.
public enum PasswordHasher {
    public static let defaultIterations = 120_000

    public static func makeHash(for password: String, iterations: Int = defaultIterations) -> PasswordHash {
        var salt = [UInt8](repeating: 0, count: 16)
        if SecRandomCopyBytes(kSecRandomDefault, salt.count, &salt) != errSecSuccess {
            salt = (0..<16).map { _ in UInt8.random(in: .min ... .max) }
        }
        let derived = derive(password: password, salt: salt, iterations: iterations)
        return PasswordHash(salt: Data(salt).base64EncodedString(), iterations: iterations, hash: Data(derived).base64EncodedString())
    }

    public static func verify(_ password: String, against stored: PasswordHash) -> Bool {
        guard let salt = Data(base64Encoded: stored.salt), let expected = Data(base64Encoded: stored.hash) else { return false }
        let derived = derive(password: password, salt: Array(salt), iterations: stored.iterations)
        guard derived.count == expected.count else { return false }
        return zip(derived, expected).reduce(0) { $0 | ($1.0 ^ $1.1) } == 0
    }

    static func derive(password: String, salt: [UInt8], iterations: Int) -> [UInt8] {
        var output = [UInt8](repeating: 0, count: 32)
        let passwordBytes = Array(password.utf8)
        _ = passwordBytes.withUnsafeBufferPointer { passwordPointer in
            CCKeyDerivationPBKDF(
                CCPBKDFAlgorithm(kCCPBKDF2),
                passwordPointer.baseAddress.map { UnsafeRawPointer($0).assumingMemoryBound(to: CChar.self) },
                passwordBytes.count,
                salt, salt.count,
                CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                UInt32(max(iterations, 1)),
                &output, output.count
            )
        }
        return output
    }
}
