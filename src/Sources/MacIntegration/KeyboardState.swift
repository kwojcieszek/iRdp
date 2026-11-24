import Carbon.HIToolbox
import CoreGraphics

/// Tracks pressed keys and modifier flags of a remote keyboard.
public struct KeyboardState: Sendable {
    public private(set) var pressedKeys: Set<UInt16> = []
    public private(set) var capsLockOn = false
    public var swapControlAndCommand: Bool

    public init(swapControlAndCommand: Bool = false) {
        self.swapControlAndCommand = swapControlAndCommand
    }

    /// Applies the Control/Command swap to a key code.
    public func translate(_ keyCode: UInt16) -> UInt16 {
        guard swapControlAndCommand else { return keyCode }
        switch Int(keyCode) {
        case kVK_Control: return UInt16(kVK_Command)
        case kVK_RightControl: return UInt16(kVK_RightCommand)
        case kVK_Command: return UInt16(kVK_Control)
        case kVK_RightCommand: return UInt16(kVK_RightControl)
        default: return keyCode
        }
    }

    /// Records a key transition. Returns `false` for a release of a key that is not pressed.
    @discardableResult
    public mutating func record(keyCode: UInt16, isDown: Bool) -> Bool {
        if keyCode == UInt16(kVK_CapsLock) {
            if isDown { capsLockOn.toggle() }
            return true
        }
        if isDown {
            pressedKeys.insert(keyCode)
            return true
        }
        return pressedKeys.remove(keyCode) != nil
    }

    public mutating func setCapsLock(_ isOn: Bool) {
        capsLockOn = isOn
    }

    public var flags: CGEventFlags {
        var flags: CGEventFlags = []
        for key in pressedKeys {
            if let modifier = ModifierKey(keyCode: key) { flags.insert(modifier.eventFlag) }
        }
        if capsLockOn { flags.insert(.maskAlphaShift) }
        return flags
    }

    /// Clears all pressed keys and returns them.
    public mutating func releaseAll() -> [UInt16] {
        defer { pressedKeys.removeAll() }
        return Array(pressedKeys)
    }
}
