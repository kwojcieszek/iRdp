import Foundation
import IRdpConfiguration
import MacIntegration
import RdpServer

/// Creates the screen capture, sound capture and input injection for a new session from the shared resources settings.
public struct MacSessionResourcesFactory: Sendable {
    public enum FactoryError: Error, CustomStringConvertible {
        case noDisplay
        case screenRecordingNotGranted

        public var description: String {
            switch self {
            case .noDisplay: "no display is available"
            case .screenRecordingNotGranted: "the Screen Recording permission is not granted to iRdp (open iRdp › Settings › Permissions on the Mac)"
            }
        }
    }

    public let resources: SharedResources

    public init(resources: SharedResources) {
        self.resources = resources
    }

    /// Size of the shared desktop, computed without creating any screen capture (used for the logon screen).
    public func desktopSize() -> DesktopSize? {
        guard let display = DisplayCatalog.display(withID: resources.displayID) else { return nil }
        return CaptureGeometry(display: display, resolution: resources.resolution).desktopSize
    }

    public func makeResources() throws -> RdpSessionResources {
        guard PermissionChecker.isScreenRecordingGranted else { throw FactoryError.screenRecordingNotGranted }
        guard let display = DisplayCatalog.display(withID: resources.displayID) else { throw FactoryError.noDisplay }
        let geometry = CaptureGeometry(display: display, resolution: resources.resolution)
        let frameSource = ScreenCaptureFrameSource(displayID: display.id, desktopSize: geometry.desktopSize, framesPerSecond: resources.quality.framesPerSecond)
        let input: (any InputSink)? = resources.shareKeyboard || resources.shareMouse
            ? CoreGraphicsInputInjector(geometry: geometry, allowsKeyboard: resources.shareKeyboard, allowsMouse: resources.shareMouse, swapControlAndCommand: resources.swapControlAndCommand)
            : nil
        let audio: (any AudioSource)? = resources.shareAudio ? ScreenCaptureAudioSource(displayID: display.id) : nil
        if let snapshots = ProcessInfo.processInfo.environment["IRDP_DEBUG_SNAPSHOT_DIR"], !snapshots.isEmpty {
            return RdpSessionResources(frameSource: DiagnosticSnapshotFrameSource(wrapping: frameSource, directory: URL(fileURLWithPath: snapshots)), inputSink: input, audioSource: audio)
        }
        return RdpSessionResources(frameSource: frameSource, inputSink: input, audioSource: audio)
    }
}
