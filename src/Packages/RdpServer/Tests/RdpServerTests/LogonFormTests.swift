import Testing
@testable import RdpServer

struct LogonFormTests {
    @Test func typesIntoFocusedFieldAndSubmits() {
        var form = LogonForm()
        #expect(form.focusedField == .userName)
        for character in "kamil" { _ = form.handle(.character(character)) }
        #expect(form.handle(.enter) == .changed, "Enter in the user name moves to the password")
        #expect(form.focusedField == .password)
        for character in "pa" { _ = form.handle(.character(character)) }
        _ = form.handle(.backspace)
        _ = form.handle(.character("x"))
        #expect(form.handle(.enter) == .submit(userName: "kamil", password: "px"))
        #expect(form.isVerifying)
        #expect(form.handle(.character("y")) == .none, "input is ignored while verifying")
    }

    @Test func startsInPasswordWhenUserNameIsKnown() {
        var form = LogonForm(userName: "kamil", message: "The user name or password is incorrect.")
        #expect(form.focusedField == .password)
        #expect(form.handle(.tab) == .changed)
        #expect(form.focusedField == .userName)
        #expect(form.userName.isEmpty, "changing the user starts with an empty name")
    }

    @Test func rejectionClearsPassword() {
        var form = LogonForm(userName: "kamil")
        _ = form.handle(.character("a"))
        _ = form.handle(.enter)
        form.rejected(message: "wrong")
        #expect(form.password.isEmpty && !form.isVerifying && form.message == "wrong")
    }

    @Test func requiresUserName() {
        var form = LogonForm()
        _ = form.handle(.tab)
        _ = form.handle(.character("p"))
        #expect(form.handle(.enter) == .changed)
        #expect(form.focusedField == .userName)
    }

    @Test func messageOnlyFormIgnoresInput() {
        var form = LogonForm.messageOnly("no permission")
        #expect(form.handle(.character("a")) == .none)
    }
}
