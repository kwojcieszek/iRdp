import RdpServer

/// Accepts exactly one user name and password.
struct FixedCredentialValidator: CredentialValidator {
    var userName: String
    var password: String

    func validate(_ credentials: ClientCredentials) async -> Bool {
        credentials.userName == userName && credentials.password == password
    }
}
