import Carbon.HIToolbox

/// Maps PC/AT set 1 scancodes sent by RDP clients to macOS virtual key codes.
public enum ScancodeKeyMap {
    public static func keyCode(scancode: UInt8, isExtended: Bool) -> UInt16? {
        isExtended ? extended[scancode] : standard[scancode]
    }

    static let standard: [UInt8: UInt16] = [
        0x01: UInt16(kVK_Escape), 0x02: UInt16(kVK_ANSI_1), 0x03: UInt16(kVK_ANSI_2), 0x04: UInt16(kVK_ANSI_3),
        0x05: UInt16(kVK_ANSI_4), 0x06: UInt16(kVK_ANSI_5), 0x07: UInt16(kVK_ANSI_6), 0x08: UInt16(kVK_ANSI_7),
        0x09: UInt16(kVK_ANSI_8), 0x0A: UInt16(kVK_ANSI_9), 0x0B: UInt16(kVK_ANSI_0), 0x0C: UInt16(kVK_ANSI_Minus),
        0x0D: UInt16(kVK_ANSI_Equal), 0x0E: UInt16(kVK_Delete), 0x0F: UInt16(kVK_Tab), 0x10: UInt16(kVK_ANSI_Q),
        0x11: UInt16(kVK_ANSI_W), 0x12: UInt16(kVK_ANSI_E), 0x13: UInt16(kVK_ANSI_R), 0x14: UInt16(kVK_ANSI_T),
        0x15: UInt16(kVK_ANSI_Y), 0x16: UInt16(kVK_ANSI_U), 0x17: UInt16(kVK_ANSI_I), 0x18: UInt16(kVK_ANSI_O),
        0x19: UInt16(kVK_ANSI_P), 0x1A: UInt16(kVK_ANSI_LeftBracket), 0x1B: UInt16(kVK_ANSI_RightBracket),
        0x1C: UInt16(kVK_Return), 0x1D: UInt16(kVK_Control), 0x1E: UInt16(kVK_ANSI_A), 0x1F: UInt16(kVK_ANSI_S),
        0x20: UInt16(kVK_ANSI_D), 0x21: UInt16(kVK_ANSI_F), 0x22: UInt16(kVK_ANSI_G), 0x23: UInt16(kVK_ANSI_H),
        0x24: UInt16(kVK_ANSI_J), 0x25: UInt16(kVK_ANSI_K), 0x26: UInt16(kVK_ANSI_L), 0x27: UInt16(kVK_ANSI_Semicolon),
        0x28: UInt16(kVK_ANSI_Quote), 0x29: UInt16(kVK_ANSI_Grave), 0x2A: UInt16(kVK_Shift), 0x2B: UInt16(kVK_ANSI_Backslash),
        0x2C: UInt16(kVK_ANSI_Z), 0x2D: UInt16(kVK_ANSI_X), 0x2E: UInt16(kVK_ANSI_C), 0x2F: UInt16(kVK_ANSI_V),
        0x30: UInt16(kVK_ANSI_B), 0x31: UInt16(kVK_ANSI_N), 0x32: UInt16(kVK_ANSI_M), 0x33: UInt16(kVK_ANSI_Comma),
        0x34: UInt16(kVK_ANSI_Period), 0x35: UInt16(kVK_ANSI_Slash), 0x36: UInt16(kVK_RightShift),
        0x37: UInt16(kVK_ANSI_KeypadMultiply), 0x38: UInt16(kVK_Option), 0x39: UInt16(kVK_Space), 0x3A: UInt16(kVK_CapsLock),
        0x3B: UInt16(kVK_F1), 0x3C: UInt16(kVK_F2), 0x3D: UInt16(kVK_F3), 0x3E: UInt16(kVK_F4), 0x3F: UInt16(kVK_F5),
        0x40: UInt16(kVK_F6), 0x41: UInt16(kVK_F7), 0x42: UInt16(kVK_F8), 0x43: UInt16(kVK_F9), 0x44: UInt16(kVK_F10),
        0x45: UInt16(kVK_ANSI_KeypadClear), 0x46: UInt16(kVK_F14), 0x47: UInt16(kVK_ANSI_Keypad7), 0x48: UInt16(kVK_ANSI_Keypad8),
        0x49: UInt16(kVK_ANSI_Keypad9), 0x4A: UInt16(kVK_ANSI_KeypadMinus), 0x4B: UInt16(kVK_ANSI_Keypad4),
        0x4C: UInt16(kVK_ANSI_Keypad5), 0x4D: UInt16(kVK_ANSI_Keypad6), 0x4E: UInt16(kVK_ANSI_KeypadPlus),
        0x4F: UInt16(kVK_ANSI_Keypad1), 0x50: UInt16(kVK_ANSI_Keypad2), 0x51: UInt16(kVK_ANSI_Keypad3),
        0x52: UInt16(kVK_ANSI_Keypad0), 0x53: UInt16(kVK_ANSI_KeypadDecimal), 0x56: UInt16(kVK_ISO_Section),
        0x57: UInt16(kVK_F11), 0x58: UInt16(kVK_F12), 0x64: UInt16(kVK_F13), 0x65: UInt16(kVK_F14), 0x66: UInt16(kVK_F15),
        0x67: UInt16(kVK_F16), 0x68: UInt16(kVK_F17), 0x69: UInt16(kVK_F18), 0x6A: UInt16(kVK_F19), 0x6B: UInt16(kVK_F20),
        0x70: UInt16(kVK_JIS_Kana), 0x73: UInt16(kVK_JIS_Underscore), 0x7D: UInt16(kVK_JIS_Yen), 0x7E: UInt16(kVK_JIS_KeypadComma),
    ]

    static let extended: [UInt8: UInt16] = [
        0x1C: UInt16(kVK_ANSI_KeypadEnter), 0x1D: UInt16(kVK_RightControl), 0x35: UInt16(kVK_ANSI_KeypadDivide),
        0x37: UInt16(kVK_F13), 0x38: UInt16(kVK_RightOption), 0x47: UInt16(kVK_Home), 0x48: UInt16(kVK_UpArrow),
        0x49: UInt16(kVK_PageUp), 0x4B: UInt16(kVK_LeftArrow), 0x4D: UInt16(kVK_RightArrow), 0x4F: UInt16(kVK_End),
        0x50: UInt16(kVK_DownArrow), 0x51: UInt16(kVK_PageDown), 0x52: UInt16(kVK_Help), 0x53: UInt16(kVK_ForwardDelete),
        0x5B: UInt16(kVK_Command), 0x5C: UInt16(kVK_RightCommand), 0x5D: UInt16(kVK_RightCommand),
        0x20: UInt16(kVK_Mute), 0x2E: UInt16(kVK_VolumeDown), 0x30: UInt16(kVK_VolumeUp),
    ]
}
