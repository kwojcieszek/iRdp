import SwiftUI

/// Menu bar icon. At launch it opens the Permissions tab when iRdp is missing a permission.
struct MenuBarLabel: View {
    @Bindable var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Image(systemName: model.menuBarSymbolName)
            .task {
                guard model.shouldPresentPermissions else { return }
                model.shouldPresentPermissions = false
                openWindow(id: SettingsView.windowID)
                NSApp.activate()
            }
    }
}
