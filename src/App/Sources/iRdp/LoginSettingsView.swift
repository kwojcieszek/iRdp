import IRdpConfiguration
import SwiftUI

/// Chooses how clients authenticate.
struct LoginSettingsView: View {
    @Bindable var model: AppModel
    @State private var newPassword = ""
    @State private var confirmation = ""
    @State private var networkPassword = ""
    @State private var networkPasswordMessage: String?

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
                Section("RDP login") {
                    Toggle("Require Network Level Authentication", isOn: $model.settings.requiresNetworkLevelAuthentication)
                    Text(model.settings.requiresNetworkLevelAuthentication
                         ? "The RDP client (Windows App, mstsc) asks for the user name and password before connecting. Wrong passwords are rejected before any session starts."
                         : "Users sign in on the iRdp logon screen inside the session.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if model.settings.requiresNetworkLevelAuthentication, model.settings.loginMode == .macOSAccount {
                        SecureField("Password of \(NSUserName())", text: $networkPassword)
                        HStack {
                            Text(networkPasswordMessage ?? (model.hasMacOSNetworkPassword ? "RDP password is set" : "RDP password is not set"))
                                .foregroundStyle(model.hasMacOSNetworkPassword && networkPasswordMessage == nil ? Color.secondary : Color.orange)
                            Spacer()
                            Button("Save RDP Password") {
                                let password = networkPassword
                                Task {
                                    let saved = await model.setMacOSNetworkPassword(password)
                                    networkPasswordMessage = saved ? nil : "This is not the password of \(NSUserName())."
                                    if saved { networkPassword = "" }
                                }
                            }
                            .disabled(networkPassword.isEmpty)
                        }
                        Text("RDP login checks the password itself, so iRdp keeps a protected hash of your macOS password. Save it again after changing your macOS password.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    if !model.settings.requiresNetworkLevelAuthentication {
                        Toggle("Always ask for the password on the iRdp logon screen", isOn: $model.settings.alwaysShowLogonScreen)
                    }
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
                Text("Connections are encrypted with TLS. The screen is captured only after a successful login.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
