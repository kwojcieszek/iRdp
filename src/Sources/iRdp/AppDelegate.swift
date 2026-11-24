import AppKit

/// Keeps the app out of the Dock when it runs outside of an app bundle with LSUIElement.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
