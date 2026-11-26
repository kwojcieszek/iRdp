import Testing
@testable import MacIntegration

struct FirewallStateTests {
    @Test func parsesSocketFilterOutput() {
        #expect(FirewallState.parse(globalState: "Firewall is disabled. (State = 0)", blockAll: "", allowSigned: "") == .disabled)
        #expect(FirewallState.parse(globalState: "Firewall is enabled. (State = 1)", blockAll: "Firewall has block all state set to disabled.", allowSigned: "Automatically allow built-in signed software ENABLED.\nAutomatically allow downloaded signed software ENABLED.") == .enabledAllowingSignedApps)
        #expect(FirewallState.parse(globalState: "Firewall is enabled. (State = 1)", blockAll: "Firewall has block all state set to disabled.", allowSigned: "Automatically allow downloaded signed software DISABLED.") == .enabled)
        #expect(FirewallState.parse(globalState: "Firewall is blocking all non-essential incoming connections. (State = 2)", blockAll: "", allowSigned: "") == .blockingAll)
        #expect(FirewallState.parse(globalState: "garbage", blockAll: "", allowSigned: "") == .unknown)
    }

    @Test func reportsWhetherClientsCanConnect() {
        #expect(FirewallState.disabled.allowsIncomingConnections)
        #expect(FirewallState.enabledAllowingSignedApps.allowsIncomingConnections)
        #expect(!FirewallState.blockingAll.allowsIncomingConnections)
    }

    @Test func readsTheRealFirewall() {
        #expect(FirewallInspector.currentState() != .unknown)
    }

    @Test func providesBonjourName() {
        #expect(LocalHostNameProvider.bonjourHostName()?.hasSuffix(".local") == true)
    }
}
