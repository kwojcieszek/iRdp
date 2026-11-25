/// State of the logon screen shown when the client did not send valid credentials.
public struct LogonForm: Sendable, Equatable {
    public static let maximumLength = 128

    public var userName: String
    public var password: String
    public var focusedField: LogonField
    public var message: String?
    /// A form without fields only shows `message` (e.g. when the screen cannot be shared).
    public var acceptsInput: Bool
    public var isVerifying = false

    public init(userName: String = "", message: String? = nil) {
        self.userName = userName
        password = ""
        focusedField = userName.isEmpty ? .userName : .password
        self.message = message
        acceptsInput = true
    }

    public static func messageOnly(_ message: String) -> LogonForm {
        var form = LogonForm(message: message)
        form.acceptsInput = false
        return form
    }

    public mutating func handle(_ key: LogonKey) -> LogonFormAction {
        guard acceptsInput, !isVerifying else { return .none }
        switch key {
        case .character(let character):
            switch focusedField {
            case .userName:
                guard userName.count < Self.maximumLength else { return .none }
                userName.append(character)
            case .password:
                guard password.count < Self.maximumLength else { return .none }
                password.append(character)
            }
            return .changed
        case .backspace:
            switch focusedField {
            case .userName:
                guard !userName.isEmpty else { return .none }
                userName.removeLast()
            case .password:
                guard !password.isEmpty else { return .none }
                password.removeLast()
            }
            return .changed
        case .tab:
            focusedField = focusedField == .userName ? .password : .userName
            return .changed
        case .escape:
            password = ""
            return .changed
        case .enter:
            if focusedField == .userName, password.isEmpty {
                focusedField = .password
                return .changed
            }
            guard !userName.isEmpty else {
                focusedField = .userName
                return .changed
            }
            isVerifying = true
            return .submit(userName: userName, password: password)
        }
    }

    /// Called when the submitted credentials were rejected.
    public mutating func rejected(message: String) {
        isVerifying = false
        password = ""
        focusedField = .password
        self.message = message
    }
}
