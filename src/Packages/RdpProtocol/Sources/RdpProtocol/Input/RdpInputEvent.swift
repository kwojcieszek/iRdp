/// Keyboard and mouse input received from an RDP client.
public enum RdpInputEvent: Sendable, Equatable {
    case keyboard(scancode: UInt8, isExtended: Bool, isRelease: Bool)
    case unicodeKeyboard(codeUnit: UInt16, isRelease: Bool)
    case mouse(flags: PointerFlags, x: UInt16, y: UInt16)
    case extendedMouse(flags: ExtendedPointerFlags, x: UInt16, y: UInt16)
    case relativeMouse(flags: PointerFlags, deltaX: Int16, deltaY: Int16)
    case synchronize(KeyboardToggleFlags)
}
