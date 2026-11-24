import Carbon.HIToolbox
import CoreGraphics

/// Modifier keys tracked by the input injector so that injected events carry the right flags.
public enum ModifierKey: CaseIterable, Sendable {
    case shift
    case control
    case option
    case command
    case capsLock

    public init?(keyCode: UInt16) {
        switch Int(keyCode) {
        case kVK_Shift, kVK_RightShift: self = .shift
        case kVK_Control, kVK_RightControl: self = .control
        case kVK_Option, kVK_RightOption: self = .option
        case kVK_Command, kVK_RightCommand: self = .command
        case kVK_CapsLock: self = .capsLock
        default: return nil
        }
    }

    public var eventFlag: CGEventFlags {
        switch self {
        case .shift: .maskShift
        case .control: .maskControl
        case .option: .maskAlternate
        case .command: .maskCommand
        case .capsLock: .maskAlphaShift
        }
    }
}
