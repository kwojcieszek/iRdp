/// A salted PBKDF2-SHA256 password hash.
public struct PasswordHash: Codable, Equatable, Sendable {
    public var salt: String
    public var iterations: Int
    public var hash: String

    public init(salt: String, iterations: Int, hash: String) {
        self.salt = salt
        self.iterations = iterations
        self.hash = hash
    }
}
