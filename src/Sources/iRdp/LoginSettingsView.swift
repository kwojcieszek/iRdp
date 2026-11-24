import IRdpConfiguration
import SwiftUI

/// Chooses how clients authenticate.
struct LoginSettingsView: View {
    @Bindable var model: AppModel
    @State private var newPassword = ""
    @State private var confirmation = ""

    var body: some View {
        Form {
            Section("Login type") {
                Picker("Clients log in with", selection: $model.settings.loginMode) {
                    ForEach(LoginMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)
            }
            switch model.settings.loginMode {
            case .none:
                Section {
                    Label("Anyone who can reach this Mac on the network can see and control the screen.", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
            case .applicationPassword:
                Section("iRdp account") {
                    TextField("User name", text: $model.settings.applicationUserName)
                    SecureField("New password", text: $newPassword)
                    SecureField("Confirm password", text: $confirmation)
                    HStack {
                        Text(model.settings.applicationPasswordHash == nil ? "No password set" : "Password is set")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Set Password") {
                            model.setApplicationPassword(newPassword)
                            newPassword = ""
                            confirmation = ""
                        }
                        .disabled(newPassword.isEmpty || newPassword != confirmation)
                    }
                }
            case .macOSAccount:
                Section("macOS account") {
                    Toggle("Only allow \(NSUserName())", isOn: $model.settings.restrictToCurrentUser)
                    Text("Clients enter the user name and password of a local macOS account.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Section {
                Text("Connections are encrypted with TLS. The RDP client must send the user name and password when connecting (save them in the client's PC or user account settings).")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
