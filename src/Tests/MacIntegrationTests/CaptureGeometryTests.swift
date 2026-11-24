import CoreGraphics
import IRdpConfiguration
import RdpServer
import Testing
@testable import MacIntegration

struct CaptureGeometryTests {
    private let display = DisplayInfo(id: 1, name: "Studio Display", bounds: CGRect(x: 0, y: 0, width: 2561, height: 1441), pixelWidth: 5122, pixelHeight: 2882, isMain: true)

    @Test func roundsDesktopSizeForRdp() {
        #expect(CaptureGeometry(display: display, resolution: .points).desktopSize == DesktopSize(width: 2560, height: 1440))
        #expect(CaptureGeometry(display: display, resolution: .native).desktopSize == DesktopSize(width: 5120, height: 2882))
        #expect(CaptureGeometry(display: display, resolution: .half).desktopSize == DesktopSize(width: 1280, height: 720))
    }

    @Test func mapsRemotePixelsToScreenPoints() {
        let geometry = CaptureGeometry(displayBounds: CGRect(x: 100, y: 50, width: 1000, height: 500), desktopSize: DesktopSize(width: 2000, height: 1000))
        let point = geometry.screenPoint(x: 1000, y: 500)
        #expect(abs(point.x - 600.25) < 0.001)
        #expect(abs(point.y - 300.25) < 0.001)
    }

    @Test func clampsCoordinatesToTheDisplay() {
        let geometry = CaptureGeometry(displayBounds: CGRect(x: 0, y: 0, width: 100, height: 100), desktopSize: DesktopSize(width: 100, height: 100))
        #expect(geometry.screenPoint(x: 500, y: -5) == CGPoint(x: 99.5, y: 0.5))
    }
}
