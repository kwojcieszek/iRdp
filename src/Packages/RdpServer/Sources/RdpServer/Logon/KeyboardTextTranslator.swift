import RdpProtocol

/// Turns scancode and Unicode input events into logon form keys, using the US layout
/// (with Polish programmer AltGr letters when the client keyboard layout is Polish).
public struct KeyboardTextTranslator: Sendable {
    public static let polishLayout: UInt32 = 0x0415

    public let keyboardLayout: UInt32
    private var shiftPressed = 0
    private var altGrPressed = false
    private var leftControlPressed = false
    private var leftAltPressed = false
    private var capsLock = false

    public init(keyboardLayout: UInt32) {
        self.keyboardLayout = keyboardLayout
    }

    private var isAltGr: Bool { altGrPressed || (leftControlPressed && leftAltPressed) }

    public mutating func translate(_ event: RdpInputEvent) -> LogonKey? {
        switch event {
        case .unicodeKeyboard(let codeUnit, let isRelease):
            guard !isRelease, let scalar = Unicode.Scalar(codeUnit) else { return nil }
            switch codeUnit {
            case 0x08: return .backspace
            case 0x09: return .tab
            case 0x0D: return .enter
            case 0x1B: return .escape
            default: return codeUnit >= 0x20 ? .character(Character(scalar)) : nil
            }
        case .synchronize(let toggles):
            capsLock = toggles.contains(.capsLock)
            shiftPressed = 0
            altGrPressed = false
            leftControlPressed = false
            leftAltPressed = false
            return nil
        case .keyboard(let scancode, let isExtended, let isRelease):
            return translateScancode(scancode, isExtended: isExtended, isRelease: isRelease)
        default:
            return nil
        }
    }

    private mutating func translateScancode(_ scancode: UInt8, isExtended: Bool, isRelease: Bool) -> LogonKey? {
        switch (scancode, isExtended) {
        case (0x2A, false), (0x36, false):
            shiftPressed = max(shiftPressed + (isRelease ? -1 : 1), 0)
            return nil
        case (0x38, true):
            altGrPressed = !isRelease
            return nil
        case (0x38, false):
            leftAltPressed = !isRelease
            return nil
        case (0x1D, false):
            leftControlPressed = !isRelease
            return nil
        case (0x3A, false):
            if !isRelease { capsLock.toggle() }
            return nil
        default:
            break
        }
        guard !isRelease else { return nil }
        switch scancode {
        case 0x0E: return .backspace
        case 0x0F: return .tab
        case 0x1C: return .enter
        case 0x01: return .escape
        default: break
        }
        if isExtended { return scancode == 0x35 ? .character("/") : nil }
        guard let (plain, shifted) = Self.usLayout[scancode] else { return nil }
        let isLetter = plain.isLetter
        let useShift = (shiftPressed > 0) != (isLetter && capsLock)
        if isAltGr {
            guard keyboardLayout & 0xFFFF == Self.polishLayout, isLetter, let polish = Self.polishAltGr[plain] else { return nil }
            return .character(useShift ? Character(polish.uppercased()) : polish)
        }
        return .character(useShift ? shifted : plain)
    }

    static let usLayout: [UInt8: (Character, Character)] = [
        0x02: ("1", "!"), 0x03: ("2", "@"), 0x04: ("3", "#"), 0x05: ("4", "$"), 0x06: ("5", "%"),
        0x07: ("6", "^"), 0x08: ("7", "&"), 0x09: ("8", "*"), 0x0A: ("9", "("), 0x0B: ("0", ")"),
        0x0C: ("-", "_"), 0x0D: ("=", "+"), 0x10: ("q", "Q"), 0x11: ("w", "W"), 0x12: ("e", "E"),
        0x13: ("r", "R"), 0x14: ("t", "T"), 0x15: ("y", "Y"), 0x16: ("u", "U"), 0x17: ("i", "I"),
        0x18: ("o", "O"), 0x19: ("p", "P"), 0x1A: ("[", "{"), 0x1B: ("]", "}"), 0x1E: ("a", "A"),
        0x1F: ("s", "S"), 0x20: ("d", "D"), 0x21: ("f", "F"), 0x22: ("g", "G"), 0x23: ("h", "H"),
        0x24: ("j", "J"), 0x25: ("k", "K"), 0x26: ("l", "L"), 0x27: (";", ":"), 0x28: ("'", "\""),
        0x29: ("`", "~"), 0x2B: ("\\", "|"), 0x2C: ("z", "Z"), 0x2D: ("x", "X"), 0x2E: ("c", "C"),
        0x2F: ("v", "V"), 0x30: ("b", "B"), 0x31: ("n", "N"), 0x32: ("m", "M"), 0x33: (",", "<"),
        0x34: (".", ">"), 0x35: ("/", "?"), 0x39: (" ", " "), 0x37: ("*", "*"), 0x4A: ("-", "-"),
        0x4E: ("+", "+"), 0x47: ("7", "7"), 0x48: ("8", "8"), 0x49: ("9", "9"), 0x4B: ("4", "4"),
        0x4C: ("5", "5"), 0x4D: ("6", "6"), 0x4F: ("1", "1"), 0x50: ("2", "2"), 0x51: ("3", "3"),
        0x52: ("0", "0"), 0x53: (".", "."),
    ]

    static let polishAltGr: [Character: Character] = [
        "a": "ą", "c": "ć", "e": "ę", "l": "ł", "n": "ń", "o": "ó", "s": "ś", "x": "ź", "z": "ż",
    ]
}
