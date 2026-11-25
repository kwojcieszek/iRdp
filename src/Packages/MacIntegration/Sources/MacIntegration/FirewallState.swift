/// State of the macOS application firewall as it affects incoming RDP connections.
public enum FirewallState: Sendable, Equatable {
    case disabled
    /// Enabled; signed apps such as iRdpService are allowed automatically.
    case enabledAllowingSignedApps
    /// Enabled and blocking all incoming connections.
    case blockingAll
    /// Enabled; iRdpService must be allowed in System Settings.
    case enabled
    case unknown

    /// Parses the output of `socketfilterfw --getglobalstate`, `--getblockall` and `--getallowsigned`.
    public static func parse(globalState: String, blockAll: String, allowSigned: String) -> FirewallState {
        let global = globalState.lowercased()
        if global.contains("disabled") || global.contains("state = 0") { return .disabled }
        guard global.contains("enabled") || global.contains("state = 1") || global.contains("state = 2") else { return .unknown }
        if blockAll.lowercased().contains("enabled") || global.contains("state = 2") { return .blockingAll }
        if allowSigned.lowercased().contains("downloaded signed software enabled") { return .enabledAllowingSignedApps }
        return .enabled
    }

    public var allowsIncomingConnections: Bool {
        switch self {
        case .disabled, .enabledAllowingSignedApps: true
        case .blockingAll, .enabled, .unknown: false
        }
    }

    public var displayText: String {
        switch self {
        case .disabled: "Firewall is off; other computers can connect."
        case .enabledAllowingSignedApps: "Firewall is on and allows signed apps such as iRdpService."
        case .blockingAll: "Firewall blocks all incoming connections. Turn off \"Block all incoming connections\" in System Settings › Network › Firewall."
        case .enabled: "Firewall is on. Allow incoming connections for iRdpService in System Settings › Network › Firewall › Options."
        case .unknown: "Firewall state is unknown."
        }
    }
}
