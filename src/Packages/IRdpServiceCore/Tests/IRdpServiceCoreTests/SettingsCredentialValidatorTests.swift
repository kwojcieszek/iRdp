import IRdpConfiguration
import RdpServer
import Testing
@testable import IRdpServiceCore

struct SettingsCredentialValidatorTests {
    private let verifier = StubAccountVerifier(userName: "kamil", password: "mac-pass", shortName: "kamil")

    @Test func noAuthenticationAcceptsEveryone() async {
        let validator = SettingsCredentialValidator(settings: ServerSettings(loginMode: .none), accountVerifier: verifier, currentUserName: "kamil")
        #expect(await validator.validate(ClientCredentials(userName: "", password: "")))
    }

    @Test func applicationPasswordChecksUserAndPassword() async {
        let settings = ServerSettings(loginMode: .applicationPassword, applicationUserName: "remote", applicationPasswordHash: PasswordHasher.makeHash(for: "p@ss", iterations: 1000))
        let validator = SettingsCredentialValidator(settings: settings, accountVerifier: verifier, currentUserName: "kamil")
        #expect(await validator.validate(ClientCredentials(userName: "Remote", password: "p@ss")))
        #expect(await validator.validate(ClientCredentials(userName: "MACSTUDIO\\remote", password: "p@ss")))
        #expect(!(await validator.validate(ClientCredentials(userName: "remote", password: "nope"))))
        #expect(!(await validator.validate(ClientCredentials(userName: "other", password: "p@ss"))))
    }

    @Test func applicationPasswordWithoutHashRejects() async {
        let validator = SettingsCredentialValidator(settings: ServerSettings(loginMode: .applicationPassword), accountVerifier: verifier, currentUserName: "kamil")
        #expect(!(await validator.validate(ClientCredentials(userName: "irdp", password: ""))))
    }

    @Test func macOSAccountUsesVerifierAndCurrentUserRestriction() async {
        let restricted = SettingsCredentialValidator(settings: ServerSettings(loginMode: .macOSAccount, restrictToCurrentUser: true), accountVerifier: verifier, currentUserName: "someone-else")
        #expect(!(await restricted.validate(ClientCredentials(userName: "kamil", password: "mac-pass"))))
        let open = SettingsCredentialValidator(settings: ServerSettings(loginMode: .macOSAccount, restrictToCurrentUser: false), accountVerifier: verifier, currentUserName: "someone-else")
        #expect(await open.validate(ClientCredentials(userName: "kamil@mac", password: "mac-pass")))
        let owner = SettingsCredentialValidator(settings: ServerSettings(loginMode: .macOSAccount), accountVerifier: verifier, currentUserName: "kamil")
        #expect(await owner.validate(ClientCredentials(userName: "kamil", password: "mac-pass")))
        #expect(!(await owner.validate(ClientCredentials(userName: "kamil", password: "bad"))))
    }

    @Test func stripsDomainDecorations() {
        #expect(SettingsCredentialValidator.plainUserName(" DOMAIN\\user ") == "user")
        #expect(SettingsCredentialValidator.plainUserName("user@host.local") == "user")
        #expect(SettingsCredentialValidator.plainUserName("user") == "user")
    }
}
