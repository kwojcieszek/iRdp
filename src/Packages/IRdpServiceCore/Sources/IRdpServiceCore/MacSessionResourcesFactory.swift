import Foundation
import IRdpConfiguration
import MacIntegration
import RdpServer

/// Creates the screen capture and input injection for a new session from the shared resources settings.
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

    public func makeResources() throws -> RdpSessionResources {
        guard PermissionChecker.isScreenRecordingGranted else { throw FactoryError.screenRecordingNotGranted }
        guard let display = DisplayCatalog.display(withID: resources.displayID) else { throw FactoryError.noDisplay }
        let geometry = CaptureGeometry(display: display, resolution: resources.resolution)
        let frameSource = ScreenCaptureFrameSource(displayID: display.id, desktopSize: geometry.desktopSize, framesPerSecond: resources.framesPerSecond)
        let input: (any InputSink)? = resources.shareKeyboard || resources.shareMouse
            ? CoreGraphicsInputInjector(geometry: geometry, allowsKeyboard: resources.shareKeyboard, allowsMouse: resources.shareMouse, swapControlAndCommand: resources.swapControlAndCommand)
            : nil
        return RdpSessionResources(frameSource: frameSource, inputSink: input)
    }
}
