/// Result of handling a key in the logon form.
public enum LogonFormAction: Sendable, Equatable {
    case none
    case changed
    case submit(userName: String, password: String)
}
