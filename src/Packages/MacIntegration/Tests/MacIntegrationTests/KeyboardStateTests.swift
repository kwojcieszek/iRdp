import Carbon.HIToolbox
import CoreGraphics
import Testing
@testable import MacIntegration

struct KeyboardStateTests {
    @Test func tracksModifierFlags() {
        var state = KeyboardState()
        state.record(keyCode: UInt16(kVK_Shift), isDown: true)
        state.record(keyCode: UInt16(kVK_Command), isDown: true)
        #expect(state.flags.contains(.maskShift))
        #expect(state.flags.contains(.maskCommand))
        state.record(keyCode: UInt16(kVK_Shift), isDown: false)
        #expect(!state.flags.contains(.maskShift))
    }

    @Test func ignoresReleaseOfKeyThatIsNotPressed() {
        var state = KeyboardState()
        let recorded = state.record(keyCode: UInt16(kVK_ANSI_A), isDown: false)
        #expect(!recorded)
    }

    @Test func togglesCapsLockOnPress() {
        var state = KeyboardState()
        state.record(keyCode: UInt16(kVK_CapsLock), isDown: true)
        state.record(keyCode: UInt16(kVK_CapsLock), isDown: false)
        #expect(state.flags.contains(.maskAlphaShift))
        state.setCapsLock(false)
        #expect(!state.flags.contains(.maskAlphaShift))
    }

    @Test func swapsControlAndCommandWhenEnabled() {
        let state = KeyboardState(swapControlAndCommand: true)
        #expect(state.translate(UInt16(kVK_Control)) == UInt16(kVK_Command))
        #expect(state.translate(UInt16(kVK_Command)) == UInt16(kVK_Control))
        #expect(state.translate(UInt16(kVK_ANSI_C)) == UInt16(kVK_ANSI_C))
        #expect(KeyboardState().translate(UInt16(kVK_Control)) == UInt16(kVK_Control))
    }

    @Test func releaseAllReturnsPressedKeys() {
        var state = KeyboardState()
        state.record(keyCode: 1, isDown: true)
        state.record(keyCode: 2, isDown: true)
        let released = state.releaseAll()
        #expect(Set(released) == [1, 2])
        #expect(state.pressedKeys.isEmpty)
    }
}
