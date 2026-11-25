import SwiftUI

/// iRdp menu bar app: controls the iRdpService and edits its settings.
@main
struct IRdpApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(model: model)
        } label: {
            MenuBarLabel(model: model)
        }
        Settings {
            SettingsView(model: model)
        }
    }
}
