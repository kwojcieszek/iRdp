import NIOCore

/// Formats peer addresses for logs and status, showing IPv4 clients of a dual-stack socket as plain IPv4.
enum RemoteAddressFormatter {
    static func string(for address: SocketAddress?) -> String {
        guard let ip = address?.ipAddress else { return "unknown" }
        return plainIPv4(ip)
    }

    static func plainIPv4(_ ip: String) -> String {
        let prefix = "::ffff:"
        if ip.lowercased().hasPrefix(prefix), ip.contains(".") { return String(ip.dropFirst(prefix.count)) }
        return ip
    }
}
