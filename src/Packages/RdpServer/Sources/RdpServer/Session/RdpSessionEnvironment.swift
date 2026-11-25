/// Collaborators the server needs to authenticate clients and serve sessions.
public struct RdpSessionEnvironment: Sendable {
    public var credentialValidator: any CredentialValidator
    public var makeSessionResources: @Sendable () async throws -> RdpSessionResources
    public var observer: (any RdpServerObserver)?

    public init(credentialValidator: any CredentialValidator, makeSessionResources: @escaping @Sendable () async throws -> RdpSessionResources, observer: (any RdpServerObserver)? = nil) {
        self.credentialValidator = credentialValidator
        self.makeSessionResources = makeSessionResources
        self.observer = observer
    }
}
