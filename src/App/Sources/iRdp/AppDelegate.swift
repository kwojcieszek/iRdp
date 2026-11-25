import AppKit

/// Keeps the app out of the Dock and handles command line actions.
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// `iRdp --start-service` / `--stop-service` controls the service and exits (useful from Terminal or scripts).
    static let startServiceArgument = "--start-service"
    static let stopServiceArgument = "--stop-service"

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let arguments = CommandLine.arguments
        guard arguments.contains(Self.startServiceArgument) || arguments.contains(Self.stopServiceArgument) else { return }
        let controller = ServiceController()
        do {
            if arguments.contains(Self.startServiceArgument) {
                try controller.start()
                print("iRdpService started")
            } else {
                try controller.stop()
                print("iRdpService stopped")
            }
            exit(0)
        } catch {
            FileHandle.standardError.write(Data("iRdp: \(error.localizedDescription)\n".utf8))
            exit(1)
        }
    }
}
