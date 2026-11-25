import IRdpConfiguration
import SwiftUI

/// Content of the menu bar menu.
struct MenuBarContentView: View {
    @Bindable var model: AppModel
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Text(model.statusSummary)
        if !model.permissions.isComplete {
            Button("⚠︎ Permissions Missing…") {
                model.selectedSettingsTab = .permissions
                NSApp.activate()
                openSettings()
            }
        }
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
        Picker("Image Quality", selection: $model.settings.sharedResources.quality) {
            ForEach(StreamQuality.allCases) { Text($0.displayName).tag($0) }
        }
        if model.requiresLoginItemApproval {
            Button("Allow in Login Items…") { model.openLoginItemsSettings() }
        }
        Button("Settings…") {
            NSApp.activate()
            openSettings()
        }
        .keyboardShortcut(",")
        Divider()
        Button("Quit iRdp") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
