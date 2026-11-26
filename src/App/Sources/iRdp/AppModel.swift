import AppKit
import Foundation
import IRdpConfiguration
import MacIntegration
import Observation
import RdpServer

/// State of the menu bar app: settings being edited and the service status.
@MainActor
@Observable
final class AppModel {
    private let settingsStore: SettingsStore
    private let statusStore: StatusStore
    private let serviceController = ServiceController()
    private var refreshTask: Task<Void, Never>?

    var settings: ServerSettings {
        didSet {
            guard settings != oldValue else { return }
            persistSettings()
        }
    }

    private(set) var status: ServiceStatus?
    private(set) var isServiceEnabled = false
    private(set) var displays: [DisplayInfo] = []
    private(set) var localAddresses: [String] = []
    private(set) var hostName: String?
    private(set) var firewallState: FirewallState = .unknown
    private(set) var permissions = PermissionState.current()
    var selectedSettingsTab: SettingsTab = .general
    /// Set at launch when a permission is missing, so the app opens the Permissions tab once.
    var shouldPresentPermissions = false
    var errorMessage: String?

    init(paths: ApplicationPaths = .standard) {
        settingsStore = SettingsStore(paths: paths)
        statusStore = StatusStore(paths: paths)
        settings = settingsStore.load()
        if settingsStore.modificationDate == nil { persistSettings() }
        refresh()
        refreshFirewallState()
        if !permissions.isComplete {
            selectedSettingsTab = .permissions
            shouldPresentPermissions = true
        }
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                self?.refresh()
            }
        }
    }

    var isServiceRunning: Bool {
        guard let status, status.isFresh() else { return false }
        return status.state == .listening || status.state == .starting
    }

    var menuBarSymbolName: String {
        if !permissions.isComplete { return "display.trianglebadge.exclamationmark" }
        if !(status?.sessions.isEmpty ?? true), isServiceRunning { return "display.2" }
        return isServiceRunning ? "display" : "display.trianglebadge.exclamationmark"
    }

    var statusSummary: String {
        guard let status, status.isFresh() else { return isServiceEnabled ? "Service is starting…" : "Service is stopped" }
        switch status.state {
        case .listening: return "Listening on port \(status.port ?? settings.port)"
        case .starting: return "Service is starting…"
        case .stopped: return "Service is stopped"
        case .failed: return "Service error: \(status.lastError ?? "unknown")"
        }
    }

    var requiresLoginItemApproval: Bool { serviceController.requiresApproval }

    func refresh() {
        status = statusStore.load()
        isServiceEnabled = serviceController.isEnabled
        displays = DisplayCatalog.activeDisplays()
        localAddresses = NetworkAddressProvider.localIPv4Addresses()
        hostName = LocalHostNameProvider.bonjourHostName()
        permissions = PermissionState.current()
    }

    /// Shows the system prompt for Screen Recording (macOS shows it only once; afterwards use System Settings).
    func requestScreenRecording() {
        if !PermissionChecker.requestScreenRecording() { openPrivacySettings(.screenRecording) }
        refresh()
    }

    /// Shows the system prompt that leads to the Accessibility settings.
    func requestAccessibility() {
        PermissionChecker.requestAccessibility()
        refresh()
    }

    func openPrivacySettings(_ pane: PrivacyPane) {
        NSWorkspace.shared.open(pane.url)
    }

    /// Restarts the service so that it picks up newly granted permissions.
    func restartService() {
        do {
            try serviceController.restart()
            errorMessage = nil
        } catch {
            errorMessage = "Cannot restart the service: \(error.localizedDescription)"
        }
        refresh()
    }

    /// Reads the firewall state off the main thread (it runs `socketfilterfw`).
    func refreshFirewallState() {
        Task.detached {
            let state = FirewallInspector.currentState()
            await MainActor.run { self.firewallState = state }
        }
    }

    /// Addresses other computers can type into their RDP client.
    var connectionAddresses: [String] {
        let suffix = settings.port == ServerSettings.defaultPort ? "" : ":\(settings.port)"
        return ([hostName].compactMap { $0 } + localAddresses).map { $0 + suffix }
    }

    func startService() {
        do {
            try serviceController.start()
            errorMessage = nil
        } catch {
            errorMessage = "Cannot start the service: \(error.localizedDescription)"
        }
        refresh()
    }

    func stopService() {
        do {
            try serviceController.stop()
            errorMessage = nil
        } catch {
            errorMessage = "Cannot stop the service: \(error.localizedDescription)"
        }
        refresh()
    }

    func setApplicationPassword(_ password: String) {
        guard !password.isEmpty else { return }
        settings.applicationPasswordHash = PasswordHasher.makeHash(for: password)
        settings.networkPasswordHashes = [settings.applicationUserName.lowercased(): Data(NtHash.of(password: password)).base64EncodedString()]
    }

    /// Saves the RDP (network level authentication) password of the logged-in macOS account after checking it.
    /// Returns false when the password is not the account's password.
    func setMacOSNetworkPassword(_ password: String) async -> Bool {
        let userName = NSUserName()
        let verified = await Task.detached { OpenDirectoryCredentialValidator().verify(userName: userName, password: password) != nil }.value
        guard verified else { return false }
        settings.networkPasswordHashes[userName.lowercased()] = Data(NtHash.of(password: password)).base64EncodedString()
        return true
    }

    var hasMacOSNetworkPassword: Bool {
        settings.networkPasswordHashes[NSUserName().lowercased()] != nil
    }

    func openLoginItemsSettings() {
        serviceController.openLoginItemsSettings()
    }

    private func persistSettings() {
        do {
            try settingsStore.save(settings)
        } catch {
            errorMessage = "Cannot save settings: \(error.localizedDescription)"
        }
    }
}
