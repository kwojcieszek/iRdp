import Foundation
import IRdpConfiguration
import MacIntegration
import os
import RdpServer

/// Runs the RDP server with the current settings and restarts it when the settings file changes.
public actor ServiceRuntime {
    private static let logger = Logger(subsystem: "com.kwojcieszek.irdp", category: "service")

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
        await PermissionChecker.triggerScreenRecordingPrompt()
        if !PermissionChecker.isAccessibilityGranted { PermissionChecker.requestAccessibility() }
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

    func applySettingsIfNeeded() async {
        let settings = settingsStore.load()
        guard settings != appliedSettings else { return }
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
            let configuration = RdpServerConfiguration(host: settings.listenAddress, port: settings.port, certificate: certificate, preferredBitsPerPixel: settings.sharedResources.colorDepth.rawValue, usesVideoEncoding: settings.sharedResources.usesVideoEncoding, videoBitRate: max(settings.sharedResources.videoBitRateMegabits, 1) * 1_000_000, framesPerSecond: settings.sharedResources.framesPerSecond)
            let factory = MacSessionResourcesFactory(resources: settings.sharedResources)
            let environment = RdpSessionEnvironment(
                credentialValidator: SettingsCredentialValidator(settings: settings, accountVerifier: OpenDirectoryCredentialValidator()),
                makeSessionResources: {
                    if ProcessInfo.processInfo.environment["IRDP_TEST_PATTERN"] == "1" {
                        return RdpSessionResources(frameSource: TestPatternFrameSource(), inputSink: nil)
                    }
                    return try factory.makeResources()
                },
                observer: reporter
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
