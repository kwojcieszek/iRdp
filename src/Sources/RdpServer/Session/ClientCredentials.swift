/// Credentials supplied by the RDP client in the Client Info PDU.
public struct ClientCredentials: Sendable, Equatable {
    public var userName: String
    public var domain: String
    public var password: String

    public init(userName: String, domain: String = "", password: String) {
        self.userName = userName
        self.domain = domain
        self.password = password
    }
}
