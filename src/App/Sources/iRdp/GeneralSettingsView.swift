import SwiftUI

/// Service control, network port and connection details.
struct GeneralSettingsView: View {
    @Bindable var model: AppModel

    var body: some View {
        Form {
            Section("Service") {
                LabeledContent("Status", value: model.statusSummary)
                HStack {
                    Button("Start Service") { model.startService() }
                        .disabled(model.isServiceRunning)
                    Button("Stop Service") { model.stopService() }
                        .disabled(!model.isServiceEnabled && !model.isServiceRunning)
                    Button("Restart Service") { model.restartService() }
                        .disabled(!model.isServiceEnabled && !model.isServiceRunning)
                }
                Text("While the service is enabled it also starts automatically when you log in.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if let errorMessage = model.errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }
            Section("Network") {
                TextField("Port", value: $model.settings.port, format: .number.grouping(.never))
                Picker("Accept connections from", selection: $model.settings.listenAddress) {
                    Text("Other computers on the network").tag("0.0.0.0")
                    Text("This Mac only").tag("127.0.0.1")
                }
                if model.settings.listenAddress == "127.0.0.1" {
                    Text("Only RDP clients running on this Mac can connect.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    LabeledContent("Connect to") {
                        VStack(alignment: .trailing) {
                            ForEach(model.connectionAddresses, id: \.self) { address in
                                Text(address).textSelection(.enabled)
                            }
                        }
                    }
                    Label(model.firewallState.displayText, systemImage: model.firewallState.allowsIncomingConnections ? "checkmark.shield" : "exclamationmark.shield")
                        .font(.footnote)
                        .foregroundStyle(model.firewallState.allowsIncomingConnections ? Color.secondary : Color.orange)
                }
            }
            if let fingerprint = model.status?.certificateFingerprint {
                Section("TLS certificate (SHA-256)") {
                    Text(fingerprint)
                        .font(.system(.footnote, design: .monospaced))
                        .textSelection(.enabled)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { model.refreshFirewallState() }
    }
}
