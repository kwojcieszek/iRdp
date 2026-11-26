import RdpProtocol
import Testing
@testable import RdpServer

struct KeyboardTextTranslatorTests {
    private func press(_ scancode: UInt8, extended: Bool = false) -> RdpInputEvent {
        .keyboard(scancode: scancode, isExtended: extended, isRelease: false)
    }

    private func release(_ scancode: UInt8, extended: Bool = false) -> RdpInputEvent {
        .keyboard(scancode: scancode, isExtended: extended, isRelease: true)
    }

    @Test func translatesLettersWithShiftAndCapsLock() {
        var translator = KeyboardTextTranslator(keyboardLayout: 0x409)
        #expect(translator.translate(press(0x1E)) == .character("a"))
        #expect(translator.translate(release(0x1E)) == nil)
        _ = translator.translate(press(0x2A))
        #expect(translator.translate(press(0x1E)) == .character("A"))
        #expect(translator.translate(press(0x02)) == .character("!"))
        _ = translator.translate(release(0x2A))
        _ = translator.translate(press(0x3A))
        #expect(translator.translate(press(0x1E)) == .character("A"))
        #expect(translator.translate(press(0x02)) == .character("1"), "Caps Lock does not shift digits")
    }

    @Test func translatesControlKeys() {
        var translator = KeyboardTextTranslator(keyboardLayout: 0x409)
        #expect(translator.translate(press(0x1C)) == .enter)
        #expect(translator.translate(press(0x0F)) == .tab)
        #expect(translator.translate(press(0x0E)) == .backspace)
        #expect(translator.translate(press(0x1C, extended: true)) == .enter)
    }

    @Test func translatesPolishAltGrLetters() {
        var translator = KeyboardTextTranslator(keyboardLayout: 0x0415)
        _ = translator.translate(press(0x38, extended: true))
        #expect(translator.translate(press(0x12)) == .character("ę"))
        _ = translator.translate(press(0x2A))
        #expect(translator.translate(press(0x26)) == .character("Ł"))
        var us = KeyboardTextTranslator(keyboardLayout: 0x409)
        _ = us.translate(press(0x38, extended: true))
        #expect(us.translate(press(0x12)) == nil)
    }

    @Test func acceptsUnicodeInput() {
        var translator = KeyboardTextTranslator(keyboardLayout: 0)
        #expect(translator.translate(.unicodeKeyboard(codeUnit: 0x0105, isRelease: false)) == .character("ą"))
        #expect(translator.translate(.unicodeKeyboard(codeUnit: 0x0D, isRelease: false)) == .enter)
        #expect(translator.translate(.unicodeKeyboard(codeUnit: 0x0105, isRelease: true)) == nil)
    }
}
