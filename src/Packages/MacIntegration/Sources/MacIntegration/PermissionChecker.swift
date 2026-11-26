import ApplicationServices
import CoreGraphics

/// Checks and requests the privacy permissions the service needs.
public enum PermissionChecker {
    public static var isScreenRecordingGranted: Bool { CGPreflightScreenCaptureAccess() }

    public static var isAccessibilityGranted: Bool { AXIsProcessTrusted() }

    /// Shows the system prompt when screen recording was not decided yet.
    @discardableResult
    public static func requestScreenRecording() -> Bool { CGRequestScreenCaptureAccess() }

    /// Shows the system prompt that leads to the Accessibility settings.
    @discardableResult
    public static func requestAccessibility() -> Bool {
        AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }
}
