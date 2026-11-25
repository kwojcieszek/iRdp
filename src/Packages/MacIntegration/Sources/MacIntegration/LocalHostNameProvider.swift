import SystemConfiguration

/// The Bonjour host name (e.g. `Mac-Studio.local`) other computers on the network can use.
public enum LocalHostNameProvider {
    public static func bonjourHostName() -> String? {
        guard let name = SCDynamicStoreCopyLocalHostName(nil) as String?, !name.isEmpty else { return nil }
        return "\(name).local"
    }
}
