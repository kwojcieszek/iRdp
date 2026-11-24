import SwiftUI

/// Settings window with one tab per area.
struct SettingsView: View {
    static let windowID = "settings"

    @Bindable var model: AppModel

    var body: some View {
        TabView {
            GeneralSettingsView(model: model)
                .tabItem { Label("General", systemImage: "gearshape") }
            LoginSettingsView(model: model)
                .tabItem { Label("Login", systemImage: "person.badge.key") }
            SharedResourcesSettingsView(model: model)
                .tabItem { Label("Shared Resources", systemImage: "display") }
            PermissionsSettingsView(model: model)
                .tabItem { Label("Permissions", systemImage: "lock.shield") }
        }
        .padding()
        .frame(width: 520)
    }
}
