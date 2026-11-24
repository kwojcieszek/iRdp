import Carbon.HIToolbox
import Testing
@testable import MacIntegration

struct ScancodeKeyMapTests {
    @Test(arguments: [
        (UInt8(0x1E), false, kVK_ANSI_A),
        (UInt8(0x1C), false, kVK_Return),
        (UInt8(0x1C), true, kVK_ANSI_KeypadEnter),
        (UInt8(0x48), true, kVK_UpArrow),
        (UInt8(0x5B), true, kVK_Command),
        (UInt8(0x38), false, kVK_Option),
        (UInt8(0x53), true, kVK_ForwardDelete),
        (UInt8(0x0E), false, kVK_Delete),
    ])
    func mapsScancodes(scancode: UInt8, isExtended: Bool, expected: Int) {
        #expect(ScancodeKeyMap.keyCode(scancode: scancode, isExtended: isExtended) == UInt16(expected))
    }

    @Test func unknownScancodesAreIgnored() {
        #expect(ScancodeKeyMap.keyCode(scancode: 0x7F, isExtended: true) == nil)
    }

    @Test func mapsAllLettersToDistinctKeys() {
        let letters: [UInt8] = Array(0x10...0x19) + Array(0x1E...0x26) + Array(0x2C...0x32)
        let codes = Set(letters.compactMap { ScancodeKeyMap.keyCode(scancode: $0, isExtended: false) })
        #expect(codes.count == 26)
    }
}
