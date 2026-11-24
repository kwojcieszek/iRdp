import Foundation
import NIOCore
import NIOPosix
import NIOSSL
import Synchronization

/// RDP server accepting Microsoft Remote Desktop clients over TLS.
public final class RdpServer: Sendable {
    private struct Runtime {
        var group: MultiThreadedEventLoopGroup
        var channel: any Channel
    }

    public let configuration: RdpServerConfiguration
    private let environment: RdpSessionEnvironment
    private let registry = RdpSessionRegistry()
    private let runtime = Mutex<Runtime?>(nil)

    public init(configuration: RdpServerConfiguration, environment: RdpSessionEnvironment) {
        self.configuration = configuration
        self.environment = environment
    }

    /// Number of sessions that completed the connection sequence.
    public var activeSessionCount: Int { registry.count }

    /// Starts listening and returns the bound port.
    @discardableResult
    public func start() async throws -> Int {
        let certificate = try NIOSSLCertificate(bytes: Array(configuration.certificate.certificatePEM.utf8), format: .pem)
        let privateKey = try NIOSSLPrivateKey(bytes: Array(configuration.certificate.privateKeyPEM.utf8), format: .pem)
        var tls = TLSConfiguration.makeServerConfiguration(certificateChain: [.certificate(certificate)], privateKey: .privateKey(privateKey))
        tls.minimumTLSVersion = .tlsv12
        let sslContext = try NIOSSLContext(configuration: tls)
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 2)
        let configuration = configuration
        let environment = environment
        let registry = registry
        let bootstrap = ServerBootstrap(group: group)
            .serverChannelOption(ChannelOptions.backlog, value: 16)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelOption(ChannelOptions.socketOption(.tcp_nodelay), value: 1)
            .childChannelOption(ChannelOptions.writeBufferWaterMark, value: .init(low: 256 * 1024, high: 1024 * 1024))
            .childChannelInitializer { channel in
                channel.eventLoop.makeCompletedFuture {
                    let operations = channel.pipeline.syncOperations
                    try operations.addHandler(ByteToMessageHandler(RdpFrameDecoder()))
                    try operations.addHandler(RdpConnectionHandler(configuration: configuration, environment: environment, sslContext: sslContext, registry: registry))
                }
            }
        do {
            let channel = try await bootstrap.bind(host: configuration.host, port: configuration.port).get()
            runtime.withLock { $0 = Runtime(group: group, channel: channel) }
            return channel.localAddress?.port ?? configuration.port
        } catch {
            try? await group.shutdownGracefully()
            throw error
        }
    }

    /// Disconnects all sessions and stops listening.
    public func stop() async {
        guard let current = runtime.withLock({ value -> Runtime? in
            defer { value = nil }
            return value
        }) else { return }
        registry.disconnectAll()
        try? await current.channel.close()
        try? await Task.sleep(for: .milliseconds(100))
        try? await current.group.shutdownGracefully()
    }
}
