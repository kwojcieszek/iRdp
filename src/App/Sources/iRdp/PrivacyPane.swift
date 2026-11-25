import Foundation

/// Privacy & Security panes in System Settings.
enum PrivacyPane {
    case screenRecording
    case accessibility

    var url: URL {
        switch self {
        case .screenRecording: URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
        case .accessibility: URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        }
    }
}
