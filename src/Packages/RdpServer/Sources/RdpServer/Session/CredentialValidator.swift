/// Decides whether a client may open a session.
public protocol CredentialValidator: Sendable {
    func validate(_ credentials: ClientCredentials) async -> Bool
}
