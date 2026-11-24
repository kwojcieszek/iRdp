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
                Picker("Color depth", selection: $model.settings.sharedResources.colorDepth) {
                    ForEach(ColorDepth.allCases) { Text($0.displayName).tag($0) }
                }
                Stepper("Frame rate: \(model.settings.sharedResources.framesPerSecond) fps", value: $model.settings.sharedResources.framesPerSecond, in: 1...60)
            }
            Section("Input") {
                Toggle("Share keyboard", isOn: $model.settings.sharedResources.shareKeyboard)
                Toggle("Share mouse", isOn: $model.settings.sharedResources.shareMouse)
                Toggle("Use Ctrl as Command (Windows key becomes Control)", isOn: $model.settings.sharedResources.swapControlAndCommand)
                    .disabled(!model.settings.sharedResources.shareKeyboard)
            }
            Section {
                Text("Only the screen image, mouse and keyboard are shared. Changes apply to new connections.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
