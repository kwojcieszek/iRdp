import SwiftUI

/// Shows whether iRdp has the privacy permissions it needs and how to grant them.
struct PermissionsSettingsView: View {
    @Bindable var model: AppModel

    var body: some View {
        Form {
            Section("iRdp needs") {
                permissionRow("Screen Recording", detail: "to send the screen image", granted: model.permissions.screenRecording, pane: .screenRecording) {
                    model.requestScreenRecording()
                }
                permissionRow("Accessibility", detail: "to control the mouse and keyboard", granted: model.permissions.accessibility, pane: .accessibility) {
                    model.requestAccessibility()
                }
            }
            if let status = model.status, status.isFresh(), model.permissions.isComplete, !(status.screenRecordingGranted && status.accessibilityGranted) {
                Section {
                    Label("The running service started before the permissions were granted.", systemImage: "arrow.clockwise")
                    Button("Restart Service") { model.restartService() }
                }
            }
            Section {
                Text("Grant the permissions to iRdp in System Settings › Privacy & Security. They also apply to iRdpService, which runs inside the app. Permissions are checked when iRdp starts.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear { model.refresh() }
    }

    private func permissionRow(_ title: String, detail: String, granted: Bool, pane: PrivacyPane, request: @escaping () -> Void) -> some View {
        HStack {
            Image(systemName: granted ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(granted ? .green : .red)
            VStack(alignment: .leading) {
                Text(title)
                Text(granted ? "Granted" : detail).font(.footnote).foregroundStyle(.secondary)
            }
            Spacer()
            if !granted {
                Button("Grant…", action: request)
                Button("Open Settings") { model.openPrivacySettings(pane) }
            }
        }
    }
}
