/// A key press understood by the logon form.
public enum LogonKey: Sendable, Equatable {
    case character(Character)
    case backspace
    case tab
    case enter
    case escape
}
