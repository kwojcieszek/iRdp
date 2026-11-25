import CoreGraphics
import Foundation
import Testing
@testable import RdpServer

struct LogonScreenRendererTests {
    private let size = DesktopSize(width: 640, height: 480)

    private func pixel(_ frame: ScreenFrame, x: Int, y: Int) -> [UInt8] {
        let offset = (y * frame.width + x) * 4
        return Array(frame.pixels[offset..<offset + 4])
    }

    @Test func rendersFrameOfRequestedSize() {
        let frame = LogonScreenRenderer(size: size, appearance: LogonScreenAppearance(defaultUserName: "kamil", displayName: "Kamil")).render(LogonForm(userName: "kamil"))
        #expect(frame.width == 640 && frame.height == 480)
        #expect(frame.pixels.count == 640 * 480 * 4)
        #expect(pixel(frame, x: 0, y: 0) != pixel(frame, x: 320, y: 300), "the avatar is drawn over the background")
    }

    @Test func typedTextChangesTheImage() {
        let renderer = LogonScreenRenderer(size: size, appearance: LogonScreenAppearance())
        var form = LogonForm()
        let before = renderer.render(form)
        _ = form.handle(.character("k"))
        #expect(before.pixels != renderer.render(form).pixels)
    }

    @Test func usesBlurredWallpaperAsBackground() throws {
        let context = try #require(CGContext(data: nil, width: 64, height: 64, bitsPerComponent: 8, bytesPerRow: 256, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue))
        context.setFillColor(CGColor(srgbRed: 0, green: 0.8, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 64, height: 64))
        let green = try #require(context.makeImage())
        let frame = LogonScreenRenderer(size: size, appearance: LogonScreenAppearance(wallpaper: green)).render(LogonForm())
        let corner = pixel(frame, x: 5, y: 5)
        #expect(corner[1] > corner[0] && corner[1] > corner[2], "the corner shows the green wallpaper")
    }

    @Test func formatsClockWithTemplate() {
        let date = Date(timeIntervalSince1970: 0)
        #expect(!LogonScreenRenderer.format(date, "H:mm").isEmpty)
    }

    @Test func wrapsLongMessages() {
        let lines = LogonScreenRenderer.wrap("one two three four five six", maximumCharacters: 10)
        #expect(lines == ["one two", "three four", "five six"])
    }
}
