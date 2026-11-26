import MacIntegration

/// Privacy permissions iRdp needs. macOS grants them to the iRdp app bundle and applies them to iRdpService inside it,
/// so the app can check them without asking the service and without showing a prompt.
struct PermissionState: Equatable {
    var screenRecording: Bool
    var accessibility: Bool

    static func current() -> PermissionState {
        PermissionState(screenRecording: PermissionChecker.isScreenRecordingGranted, accessibility: PermissionChecker.isAccessibilityGranted)
    }

    var isComplete: Bool { screenRecording && accessibility }
}
