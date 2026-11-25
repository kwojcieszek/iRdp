import SwiftUI

/// Settings window with one tab per area.
struct SettingsView: View {
    static let windowID = "settings"

    @Bindable var model: AppModel

    var body: some View {
        TabView(selection: $model.selectedSettingsTab) {
            GeneralSettingsView(model: model)
                .tabItem { Label("General", systemImage: "gearshape") }
                .tag(SettingsTab.general)
            LoginSettingsView(model: model)
                .tabItem { Label("Login", systemImage: "person.badge.key") }
                .tag(SettingsTab.login)
            SharedResourcesSettingsView(model: model)
                .tabItem { Label("Shared Resources", systemImage: "display") }
                .tag(SettingsTab.sharedResources)
            PermissionsSettingsView(model: model)
                .tabItem { Label("Permissions", systemImage: "lock.shield") }
                .tag(SettingsTab.permissions)
        }
        .padding()
        .frame(width: 520)
    }
}
