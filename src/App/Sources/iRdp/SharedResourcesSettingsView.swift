import IRdpConfiguration
import SwiftUI

/// Chooses the shared display, image quality and which input devices remote users may control.
struct SharedResourcesSettingsView: View {
    @Bindable var model: AppModel

    var body: some View {
        Form {
            Section("Screen") {
                Picker("Display", selection: $model.settings.sharedResources.displayID) {
                    Text("Main display").tag(UInt32?.none)
                    ForEach(model.displays) { display in
                        Text("\(display.name) (\(Int(display.bounds.width))×\(Int(display.bounds.height)))").tag(UInt32?.some(display.id))
                    }
                }
                Picker("Resolution", selection: $model.settings.sharedResources.resolution) {
                    ForEach(CaptureResolution.allCases) { Text($0.displayName).tag($0) }
                }
            }
            Section("Image quality") {
                Picker("Quality", selection: $model.settings.sharedResources.quality) {
                    ForEach(StreamQuality.allCases) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.segmented)
                Text(model.settings.sharedResources.quality.summary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Toggle("Hardware H.264 encoding (lowest latency)", isOn: $model.settings.sharedResources.usesVideoEncoding)
                Text("Quality changes apply immediately, also to connected clients. H.264 is used with clients that support the RDP graphics pipeline (Windows App, mstsc).")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Section("Input") {
                Toggle("Share keyboard", isOn: $model.settings.sharedResources.shareKeyboard)
                Toggle("Share mouse", isOn: $model.settings.sharedResources.shareMouse)
                Toggle("Use Ctrl as Command (Windows key becomes Control)", isOn: $model.settings.sharedResources.swapControlAndCommand)
                    .disabled(!model.settings.sharedResources.shareKeyboard)
            }
            Section {
                Text("Only the screen image, mouse and keyboard are shared. Display, resolution and input changes apply to new connections.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
