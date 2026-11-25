import Testing
@testable import RdpServer

struct LogonScreenRendererTests {
    @Test func rendersFrameOfRequestedSize() {
        let frame = LogonScreenRenderer.render(LogonForm(userName: "kamil"), size: DesktopSize(width: 640, height: 480), serverName: "Mac-Studio")
        #expect(frame.width == 640 && frame.height == 480)
        #expect(frame.pixels.count == 640 * 480 * 4)
        let corner = Array(frame.pixels[0..<4])
        let center = Array(frame.pixels[((240 * 640) + 320) * 4..<((240 * 640) + 321) * 4])
        #expect(corner != center, "the panel is drawn over the background")
    }

    @Test func typedTextChangesTheImage() {
        let size = DesktopSize(width: 640, height: 480)
        var form = LogonForm()
        let before = LogonScreenRenderer.render(form, size: size, serverName: "Mac")
        _ = form.handle(.character("k"))
        let after = LogonScreenRenderer.render(form, size: size, serverName: "Mac")
        #expect(before.pixels != after.pixels)
    }

    @Test func wrapsLongMessages() {
        let lines = LogonScreenRenderer.wrap("one two three four five six", maximumCharacters: 10)
        #expect(lines == ["one two", "three four", "five six"])
    }
}
