import IRdpServiceCore

/// Accepts one account and reports it under its short name.
struct StubAccountVerifier: AccountVerifier {
    var userName: String
    var password: String
    var shortName: String

    func verify(userName: String, password: String) -> String? {
        userName == self.userName && password == self.password ? shortName : nil
    }
}
