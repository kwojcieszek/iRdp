import AppKit

/// Keeps the app out of the Dock and handles command line actions.
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// `iRdp --start-service`, `--stop-service` and `--restart-service` control the service and exit (for Terminal or scripts).
    static let startServiceArgument = "--start-service"
    static let stopServiceArgument = "--stop-service"
    static let restartServiceArgument = "--restart-service"

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let arguments = CommandLine.arguments
        let actions = [Self.startServiceArgument, Self.stopServiceArgument, Self.restartServiceArgument]
        guard let action = arguments.first(where: actions.contains) else { return }
        let controller = ServiceController()
        do {
            switch action {
            case Self.startServiceArgument:
                try controller.start()
                print("iRdpService started")
            case Self.restartServiceArgument:
                try controller.restart()
                print("iRdpService restarted")
            default:
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
