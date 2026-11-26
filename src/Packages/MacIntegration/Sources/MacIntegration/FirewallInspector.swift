import Foundation

/// Reads the application firewall settings with `socketfilterfw` (read-only, no administrator rights needed).
public enum FirewallInspector {
    static let toolURL = URL(fileURLWithPath: "/usr/libexec/ApplicationFirewall/socketfilterfw")

    public static func currentState() -> FirewallState {
        guard let global = run("--getglobalstate") else { return .unknown }
        return FirewallState.parse(globalState: global, blockAll: run("--getblockall") ?? "", allowSigned: run("--getallowsigned") ?? "")
    }

    private static func run(_ argument: String) -> String? {
        let process = Process()
        process.executableURL = toolURL
        process.arguments = [argument]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
        } catch {
            return nil
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(decoding: data, as: UTF8.self)
    }
}
