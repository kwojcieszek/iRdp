/// Collaborators the server needs to authenticate clients and serve sessions.
public struct RdpSessionEnvironment: Sendable {
    public var credentialValidator: any CredentialValidator
    public var makeSessionResources: @Sendable () async throws -> RdpSessionResources
    public var observer: (any RdpServerObserver)?
    /// Look of the logon screen shown when the client sends no valid credentials.
    public var logonAppearance: @Sendable () -> LogonScreenAppearance
    /// Size of the shared desktop without creating any screen capture. When set, `makeSessionResources`
    /// is only called after a successful login, so nothing that can see the screen exists before it.
    public var desktopSize: (@Sendable () -> DesktopSize?)?
    /// NT hash of an account's password, used to verify network level authentication (NTLM).
    public var ntHash: @Sendable (String) -> [UInt8]?

    public init(credentialValidator: any CredentialValidator, makeSessionResources: @escaping @Sendable () async throws -> RdpSessionResources, observer: (any RdpServerObserver)? = nil, logonAppearance: @escaping @Sendable () -> LogonScreenAppearance = { LogonScreenAppearance() }, desktopSize: (@Sendable () -> DesktopSize?)? = nil, ntHash: @escaping @Sendable (String) -> [UInt8]? = { _ in nil }) {
        self.credentialValidator = credentialValidator
        self.makeSessionResources = makeSessionResources
        self.observer = observer
        self.logonAppearance = logonAppearance
        self.desktopSize = desktopSize
        self.ntHash = ntHash
    }
}
