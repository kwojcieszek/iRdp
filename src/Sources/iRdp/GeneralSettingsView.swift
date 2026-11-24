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
                    Text("All networks").tag("0.0.0.0")
                    Text("This Mac only").tag("127.0.0.1")
                }
                if !model.localAddresses.isEmpty {
                    LabeledContent("Connect to") {
                        VStack(alignment: .trailing) {
                            ForEach(model.localAddresses, id: \.self) { address in
                                Text(model.settings.port == 3389 ? address : "\(address):\(model.settings.port)")
                                    .textSelection(.enabled)
                            }
                        }
                    }
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
    }
}
