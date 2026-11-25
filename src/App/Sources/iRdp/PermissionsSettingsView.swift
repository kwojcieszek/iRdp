import AppKit
import SwiftUI

/// Shows whether the service has the privacy permissions it needs.
struct PermissionsSettingsView: View {
    @Bindable var model: AppModel

    private static let screenRecordingURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
    private static let accessibilityURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")

    var body: some View {
        Form {
            Section("iRdpService needs") {
                permissionRow("Screen Recording", detail: "to send the screen image", granted: model.status?.screenRecordingGranted, url: Self.screenRecordingURL)
                permissionRow("Accessibility", detail: "to control the mouse and keyboard", granted: model.status?.accessibilityGranted, url: Self.accessibilityURL)
            }
            Section {
                Text("Permissions are reported by the running service. After granting a permission, stop and start the service.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private func permissionRow(_ title: String, detail: String, granted: Bool?, url: URL?) -> some View {
        HStack {
            Image(systemName: granted == true ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(granted == true ? .green : .red)
            VStack(alignment: .leading) {
                Text(title)
                Text(detail).font(.footnote).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Open Settings") {
                if let url { NSWorkspace.shared.open(url) }
            }
        }
    }
}
