import IRdpConfiguration
import SwiftUI

/// Content of the menu bar menu.
struct MenuBarContentView: View {
    @Bindable var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Text(model.statusSummary)
        if model.isServiceRunning, model.settings.listenAddress != "127.0.0.1", let address = model.connectionAddresses.first {
            Text("Connect to \(address)")
        }
        if let sessions = model.status?.sessions, model.isServiceRunning, !sessions.isEmpty {
            ForEach(sessions) { session in
                Text("\(session.userName.isEmpty ? "Guest" : session.userName) — \(session.clientName) (\(session.remoteAddress))")
            }
        } else if model.isServiceRunning {
            Text("No connected clients")
        }
        if let errorMessage = model.errorMessage {
            Text(errorMessage)
        }
        Divider()
        if model.isServiceEnabled || model.isServiceRunning {
            Button("Stop Service") { model.stopService() }
        } else {
            Button("Start Service") { model.startService() }
        }
        if model.requiresLoginItemApproval {
            Button("Allow in Login Items…") { model.openLoginItemsSettings() }
        }
        Button("Settings…") {
            openWindow(id: SettingsView.windowID)
            NSApp.activate()
        }
        .keyboardShortcut(",")
        Divider()
        Button("Quit iRdp") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
