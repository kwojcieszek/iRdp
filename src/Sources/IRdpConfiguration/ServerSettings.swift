import Foundation

/// Settings shared by the menu bar app (writer) and the service (reader).
public struct ServerSettings: Codable, Equatable, Sendable {
    public static let defaultPort = 3389

    public var port: Int
    public var listenAddress: String
    public var loginMode: LoginMode
    public var applicationUserName: String
    public var applicationPasswordHash: PasswordHash?
    /// With `macOSAccount`, only the user who owns the shared desktop may log in.
    public var restrictToCurrentUser: Bool
    public var sharedResources: SharedResources

    public init(port: Int = defaultPort, listenAddress: String = "0.0.0.0", loginMode: LoginMode = .macOSAccount, applicationUserName: String = "irdp", applicationPasswordHash: PasswordHash? = nil, restrictToCurrentUser: Bool = true, sharedResources: SharedResources = SharedResources()) {
        self.port = port
        self.listenAddress = listenAddress
        self.loginMode = loginMode
        self.applicationUserName = applicationUserName
        self.applicationPasswordHash = applicationPasswordHash
        self.restrictToCurrentUser = restrictToCurrentUser
        self.sharedResources = sharedResources
    }

    public init(from decoder: any Decoder) throws {
        let defaults = ServerSettings()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        port = try container.decodeIfPresent(Int.self, forKey: .port) ?? defaults.port
        listenAddress = try container.decodeIfPresent(String.self, forKey: .listenAddress) ?? defaults.listenAddress
        loginMode = try container.decodeIfPresent(LoginMode.self, forKey: .loginMode) ?? defaults.loginMode
        applicationUserName = try container.decodeIfPresent(String.self, forKey: .applicationUserName) ?? defaults.applicationUserName
        applicationPasswordHash = try container.decodeIfPresent(PasswordHash.self, forKey: .applicationPasswordHash)
        restrictToCurrentUser = try container.decodeIfPresent(Bool.self, forKey: .restrictToCurrentUser) ?? defaults.restrictToCurrentUser
        sharedResources = try container.decodeIfPresent(SharedResources.self, forKey: .sharedResources) ?? defaults.sharedResources
    }

    /// Problems that prevent the service from accepting clients with these settings.
    public var validationIssues: [String] {
        var issues: [String] = []
        if !(1...65535).contains(port) { issues.append("Port must be between 1 and 65535.") }
        if loginMode == .applicationPassword {
            if applicationUserName.trimmingCharacters(in: .whitespaces).isEmpty { issues.append("User name is empty.") }
            if applicationPasswordHash == nil { issues.append("Password is not set.") }
        }
        return issues
    }
}
