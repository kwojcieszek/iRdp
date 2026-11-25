import ApplicationServices
import CoreGraphics
import ScreenCaptureKit

/// Checks and requests the privacy permissions the service needs.
public enum PermissionChecker {
    public static var isScreenRecordingGranted: Bool { CGPreflightScreenCaptureAccess() }

    public static var isAccessibilityGranted: Bool { AXIsProcessTrusted() }

    /// Shows the system prompt when screen recording was not decided yet.
    @discardableResult
    public static func requestScreenRecording() -> Bool { CGRequestScreenCaptureAccess() }

    /// Asks ScreenCaptureKit for shareable content, which makes macOS show the Screen Recording prompt
    /// (and list iRdpService in System Settings) even for a background process.
    public static func triggerScreenRecordingPrompt() async {
        guard !isScreenRecordingGranted else { return }
        CGRequestScreenCaptureAccess()
        _ = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
    }

    /// Shows the system prompt that leads to the Accessibility settings.
    @discardableResult
    public static func requestAccessibility() -> Bool {
        AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }
}
