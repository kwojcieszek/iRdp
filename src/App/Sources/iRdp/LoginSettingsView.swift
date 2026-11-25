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
            if model.settings.loginMode != .none {
                Section {
                    Toggle("Always ask for the password on the iRdp logon screen", isOn: $model.settings.alwaysShowLogonScreen)
                    Text("When on, passwords saved in RDP clients such as Windows App are ignored and everyone signs in on the logon screen.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
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
                Text("Connections are encrypted with TLS. Users sign in on the iRdp logon screen, or with credentials saved in the RDP client when the option above is off.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
