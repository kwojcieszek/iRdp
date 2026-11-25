import CoreGraphics
import Foundation
import ImageIO
import RdpServer
import Testing
import UniformTypeIdentifiers
@testable import MacIntegration

/// Renders the logon screen with this Mac's wallpaper and account picture.
/// Writes PNG previews when IRDP_PREVIEW_DIR is set.
struct LogonScreenPreviewTests {
    private func savePNG(_ frame: ScreenFrame, to url: URL) throws {
        let data = Data(frame.pixels)
        guard let provider = CGDataProvider(data: data as CFData),
              let image = CGImage(width: frame.width, height: frame.height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: frame.bytesPerRow, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue), provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent),
              let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else { return }
        CGImageDestinationAddImage(destination, image, nil)
        CGImageDestinationFinalize(destination)
    }

    @Test func rendersWithTheMacAppearance() throws {
        let appearance = LogonAppearanceProvider.appearance(userName: NSUserName(), displayName: NSFullUserName(), displayID: nil, serverName: Host.current().localizedName)
        let renderer = LogonScreenRenderer(size: DesktopSize(width: 1920, height: 1080), appearance: appearance)
        var form = LogonForm(userName: NSUserName())
        for character in "secret" { _ = form.handle(.character(character)) }
        let typing = renderer.render(form)
        form.rejected(message: "The user name or password is incorrect.")
        let rejected = renderer.render(form)
        var other = LogonForm(userName: NSUserName())
        _ = other.handle(.tab)
        for character in "guest" { _ = other.handle(.character(character)) }
        let otherUser = renderer.render(other)
        #expect(typing.pixels != rejected.pixels)
        #expect(typing.pixels != otherUser.pixels)
        if let directory = ProcessInfo.processInfo.environment["IRDP_PREVIEW_DIR"] {
            let base = URL(fileURLWithPath: directory)
            try savePNG(typing, to: base.appendingPathComponent("logon-password.png"))
            try savePNG(rejected, to: base.appendingPathComponent("logon-rejected.png"))
            try savePNG(otherUser, to: base.appendingPathComponent("logon-other-user.png"))
        }
    }
}
