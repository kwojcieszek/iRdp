import MacIntegration

/// Verifies a local account password and returns the account's short name.
public protocol AccountVerifier: Sendable {
    func verify(userName: String, password: String) -> String?
}

extension OpenDirectoryCredentialValidator: AccountVerifier {}
