import Foundation
import IRdpConfiguration
import RdpServer

/// Authenticates clients according to the configured login mode.
public struct SettingsCredentialValidator: CredentialValidator {
    public let settings: ServerSettings
    public let accountVerifier: any AccountVerifier
    public let currentUserName: String

    public init(settings: ServerSettings, accountVerifier: any AccountVerifier, currentUserName: String = NSUserName()) {
        self.settings = settings
        self.accountVerifier = accountVerifier
        self.currentUserName = currentUserName
    }

    public func validate(_ credentials: ClientCredentials) async -> Bool {
        switch settings.loginMode {
        case .none:
            return true
        case .applicationPassword:
            guard let hash = settings.applicationPasswordHash else { return false }
            let expectedUser = settings.applicationUserName.trimmingCharacters(in: .whitespaces)
            guard Self.plainUserName(credentials.userName).caseInsensitiveCompare(expectedUser) == .orderedSame else { return false }
            return PasswordHasher.verify(credentials.password, against: hash)
        case .macOSAccount:
            let userName = Self.plainUserName(credentials.userName)
            let verifier = accountVerifier
            let password = credentials.password
            let accountName = await Task.detached { verifier.verify(userName: userName, password: password) }.value
            guard let accountName else { return false }
            return !settings.restrictToCurrentUser || accountName == currentUserName
        }
    }

    /// Strips `DOMAIN\user` and `user@domain` decorations.
    static func plainUserName(_ name: String) -> String {
        var result = name.trimmingCharacters(in: .whitespaces)
        if let backslash = result.lastIndex(of: "\\") { result = String(result[result.index(after: backslash)...]) }
        if let at = result.firstIndex(of: "@") { result = String(result[..<at]) }
        return result
    }
}
