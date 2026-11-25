import Foundation
import IRdpConfiguration
import MacIntegration
import os
import RdpServer

/// Runs the RDP server with the current settings and restarts it when the settings file changes.
public actor ServiceRuntime {
    private static let logger = Logger(subsystem: "com.irdp", category: "service")

    private let paths: ApplicationPaths
    private let settingsStore: SettingsStore
    private let reporter: ServiceStatusReporter
    private var server: RdpServer?
    private var appliedSettings: ServerSettings?
    private var isStopping = false

    public init(paths: ApplicationPaths = .standard) {
        self.paths = paths
        settingsStore = SettingsStore(paths: paths)
        reporter = ServiceStatusReporter(store: StatusStore(paths: paths))
    }

    /// Runs until `stop()` is called.
    public func run(pollInterval: Duration = .seconds(2)) async {
        Self.logger.info("iRdpService starting")
        // The service never shows permission prompts itself: the menu bar app checks and requests them,
        // and macOS attributes the service's access to the app (same bundle).
        while !isStopping {
            await applySettingsIfNeeded()
            reporter.update { _ in }
            try? await Task.sleep(for: pollInterval)
        }
    }

    public func stop() async {
        isStopping = true
        await server?.stop()
        server = nil
        reporter.update {
            $0.state = .stopped
            $0.port = nil
            $0.sessions = []
        }
    }

    static func streamingQuality(for quality: StreamQuality) -> StreamingQuality {
        StreamingQuality(videoBitRate: quality.videoBitRate, framesPerSecond: quality.framesPerSecond, bitsPerPixel: quality.bitsPerPixel, sharpensStillImages: quality.sharpensStillImages)
    }

    /// True when the only difference is the stream quality, which running sessions can apply without a restart.
    static func differOnlyInQuality(_ lhs: ServerSettings, _ rhs: ServerSettings) -> Bool {
        var left = lhs
        var right = rhs
        left.sharedResources = lhs.sharedResources.ignoringQuality()
        right.sharedResources = rhs.sharedResources.ignoringQuality()
        return left == right && lhs.sharedResources.quality != rhs.sharedResources.quality
    }

    /// The account the logon screen suggests: the logged-in user for macOS accounts, the iRdp user otherwise.
    static func suggestedAccount(for settings: ServerSettings) -> (userName: String?, displayName: String?) {
        switch settings.loginMode {
        case .macOSAccount: (NSUserName(), NSFullUserName())
        case .applicationPassword: (settings.applicationUserName, settings.applicationUserName)
        case .none: (nil, nil)
        }
    }

    func applySettingsIfNeeded() async {
        let settings = settingsStore.load()
        guard settings != appliedSettings else { return }
        if let applied = appliedSettings, let server, Self.differOnlyInQuality(applied, settings) {
            appliedSettings = settings
            server.updateQuality(Self.streamingQuality(for: settings.sharedResources.quality))
            Self.logger.info("streaming quality changed to \(settings.sharedResources.quality.rawValue, privacy: .public)")
            return
        }
        appliedSettings = settings
        await server?.stop()
        server = nil
        reporter.update {
            $0.state = .starting
            $0.sessions = []
        }
        let issues = settings.validationIssues
        guard issues.isEmpty else {
            reporter.update {
                $0.state = .failed
                $0.port = nil
                $0.lastError = issues.joined(separator: " ")
            }
            return
        }
        do {
            let certificate = try TlsCertificateStore(directory: paths.certificateDirectory).loadOrCreate(commonName: Host.current().localizedName ?? "iRdp")
            let fingerprint = try? SelfSignedCertificateGenerator.fingerprint(ofCertificatePEM: certificate.certificatePEM)
            let configuration = RdpServerConfiguration(host: settings.listenAddress, port: settings.port, certificate: certificate, usesVideoEncoding: settings.sharedResources.usesVideoEncoding, quality: Self.streamingQuality(for: settings.sharedResources.quality), alwaysShowsLogonScreen: settings.alwaysShowLogonScreen && settings.loginMode != .none)
            let factory = MacSessionResourcesFactory(resources: settings.sharedResources)
            let environment = RdpSessionEnvironment(
                credentialValidator: SettingsCredentialValidator(settings: settings, accountVerifier: OpenDirectoryCredentialValidator()),
                makeSessionResources: {
                    if ProcessInfo.processInfo.environment["IRDP_TEST_PATTERN"] == "1" {
                        return RdpSessionResources(frameSource: TestPatternFrameSource(), inputSink: nil)
                    }
                    return try factory.makeResources()
                },
                observer: reporter,
                logonAppearance: {
                    let suggested = Self.suggestedAccount(for: settings)
                    return LogonAppearanceProvider.appearance(userName: suggested.userName, displayName: suggested.displayName, displayID: settings.sharedResources.displayID, serverName: Host.current().localizedName)
                }
            )
            let server = RdpServer(configuration: configuration, environment: environment)
            let port = try await server.start()
            self.server = server
            reporter.update {
                $0.state = .listening
                $0.port = port
                $0.lastError = nil
                $0.certificateFingerprint = fingerprint
            }
            Self.logger.info("listening on \(settings.listenAddress, privacy: .public):\(port)")
        } catch {
            Self.logger.error("cannot start server: \(String(describing: error), privacy: .public)")
            reporter.update {
                $0.state = .failed
                $0.port = nil
                $0.lastError = "Cannot listen on port \(settings.port): \(error)"
            }
            appliedSettings = nil
        }
    }
}
