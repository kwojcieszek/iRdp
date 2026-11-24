import CoreGraphics
import IRdpConfiguration
import RdpServer

/// Relates the remote desktop size to the shared display and maps remote coordinates to screen points.
public struct CaptureGeometry: Sendable, Equatable {
    public var displayBounds: CGRect
    public var desktopSize: DesktopSize

    public init(displayBounds: CGRect, desktopSize: DesktopSize) {
        self.displayBounds = displayBounds
        self.desktopSize = desktopSize
    }

    /// Chooses the desktop size for a display: width rounded down to a multiple of 4, height to a multiple of 2.
    public init(display: DisplayInfo, resolution: CaptureResolution) {
        let width: Double
        let height: Double
        switch resolution {
        case .points:
            width = display.bounds.width
            height = display.bounds.height
        case .native:
            width = Double(display.pixelWidth)
            height = Double(display.pixelHeight)
        case .half:
            width = display.bounds.width / 2
            height = display.bounds.height / 2
        }
        let clampedWidth = min(max(Int(width), 64), 8192) & ~3
        let clampedHeight = min(max(Int(height), 64), 8192) & ~1
        self.init(displayBounds: display.bounds, desktopSize: DesktopSize(width: clampedWidth, height: clampedHeight))
    }

    /// Converts a remote pixel position to a global screen point, clamped to the display.
    public func screenPoint(x: Int, y: Int) -> CGPoint {
        let clampedX = min(max(x, 0), desktopSize.width - 1)
        let clampedY = min(max(y, 0), desktopSize.height - 1)
        let scaleX = displayBounds.width / Double(desktopSize.width)
        let scaleY = displayBounds.height / Double(desktopSize.height)
        return CGPoint(x: displayBounds.minX + (Double(clampedX) + 0.5) * scaleX, y: displayBounds.minY + (Double(clampedY) + 0.5) * scaleY)
    }
}
