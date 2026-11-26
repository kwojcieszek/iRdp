import Foundation
import NIOCore
import RdpProtocol
import Testing
@testable import RdpServer

/// Verifies that clients on other machines (non-loopback addresses, IPv4 and IPv6) can connect.
@Suite(.serialized, .timeLimit(.minutes(1)))
struct RdpServerNetworkTests {
    private func makeServer(host: String, throttle: AuthenticationThrottle = AuthenticationThrottle()) -> RdpServer {
        let environment = RdpSessionEnvironment(
            credentialValidator: FixedCredentialValidator(userName: "kamil", password: "secret"),
            makeSessionResources: { RdpSessionResources(frameSource: TestPatternFrameSource(desktopSize: DesktopSize(width: 128, height: 64)), inputSink: nil) }
        )
        return RdpServer(configuration: RdpServerConfiguration(host: host, port: 0, certificate: TestCertificate.shared), environment: environment, throttle: throttle)
    }

    /// First IPv4 address of this machine that is not loopback, i.e. what another computer on the LAN would use.
    private func lanAddress() throws -> String? {
        try System.enumerateDevices().compactMap { device -> String? in
            guard let address = device.address, case .v4 = address, let ip = address.ipAddress, !ip.hasPrefix("127.") else { return nil }
            return ip
        }.first
    }

    private func activate(host: String, port: Int) async throws {
        let (client, confirm) = try await RdpTestClient.connect(host: host, port: port)
        #expect(confirm.outcome == .selected(.tls, flags: X224ConnectionConfirm.extendedClientDataSupported | X224ConnectionConfirm.dynamicVirtualChannelGraphicsSupported))
        let session = try await client.connectSession(userName: "kamil", password: "secret")
        let bitmap = try await session.activate()
        #expect(bitmap.desktopWidth == 128)
        await session.close()
    }

    @Test func allNetworksAcceptsLanIPv4AndIPv6Clients() async throws {
        let server = makeServer(host: "0.0.0.0")
        let port = try await server.start()
        defer { Task { await server.stop() } }
        try await activate(host: "127.0.0.1", port: port)
        try await activate(host: "::1", port: port)
        if let lan = try lanAddress() {
            try await activate(host: lan, port: port)
        }
    }

    @Test func thisMacOnlyRefusesLanClients() async throws {
        let server = makeServer(host: "127.0.0.1")
        let port = try await server.start()
        defer { Task { await server.stop() } }
        try await activate(host: "127.0.0.1", port: port)
        guard let lan = try lanAddress() else { return }
        await #expect(throws: (any Error).self) { _ = try await RdpTestClient.connect(host: lan, port: port) }
    }

    @Test func repeatedWrongPasswordsLockOutTheAddress() async throws {
        let server = makeServer(host: "127.0.0.1", throttle: AuthenticationThrottle(maximumFailures: 2, window: 60, lockoutDuration: 60))
        let port = try await server.start()
        defer { Task { await server.stop() } }
        for _ in 0..<2 {
            let session = try await RdpTestClient.connect(port: port).0.connectSession(userName: "kamil", password: "wrong")
            _ = try await session.activate()
            await session.close()
        }
        let locked = try await RdpTestClient.connect(port: port).0.connectSession(userName: "kamil", password: "secret")
        await #expect(throws: (any Error).self) { _ = try await locked.activate() }
        await locked.close()
    }
}
