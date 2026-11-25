/// Collaborators the server needs to authenticate clients and serve sessions.
public struct RdpSessionEnvironment: Sendable {
    public var credentialValidator: any CredentialValidator
    public var makeSessionResources: @Sendable () async throws -> RdpSessionResources
    public var observer: (any RdpServerObserver)?
    /// Look of the logon screen shown when the client sends no valid credentials.
    public var logonAppearance: @Sendable () -> LogonScreenAppearance

    public init(credentialValidator: any CredentialValidator, makeSessionResources: @escaping @Sendable () async throws -> RdpSessionResources, observer: (any RdpServerObserver)? = nil, logonAppearance: @escaping @Sendable () -> LogonScreenAppearance = { LogonScreenAppearance() }) {
        self.credentialValidator = credentialValidator
        self.makeSessionResources = makeSessionResources
        self.observer = observer
        self.logonAppearance = logonAppearance
    }
}
