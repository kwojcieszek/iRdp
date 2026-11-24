import Foundation
import IRdpConfiguration
import MacIntegration
import os
import RdpServer
import Synchronization

/// Collects the service state and publishes it to the status file.
public final class ServiceStatusReporter: RdpServerObserver {
    private static let logger = Logger(subsystem: "com.kwojcieszek.irdp", category: "status")

    private let store: StatusStore
    private let status: Mutex<ServiceStatus>

    public init(store: StatusStore) {
        self.store = store
        status = Mutex(ServiceStatus(state: .starting, processIdentifier: ProcessInfo.processInfo.processIdentifier))
    }

    public var current: ServiceStatus { status.withLock { $0 } }

    public func update(_ change: (inout ServiceStatus) -> Void) {
        let snapshot = status.withLock { value -> ServiceStatus in
            change(&value)
            value.updatedAt = Date()
            value.screenRecordingGranted = PermissionChecker.isScreenRecordingGranted
            value.accessibilityGranted = PermissionChecker.isAccessibilityGranted
            return value
        }
        do {
            try store.save(snapshot)
        } catch {
            Self.logger.error("cannot write status: \(error.localizedDescription, privacy: .public)")
        }
    }

    public func sessionDidStart(_ session: RdpSessionInfo) {
        update {
            $0.sessions.append(SessionStatus(id: session.id, remoteAddress: session.remoteAddress, clientName: session.clientName, userName: session.userName, width: session.desktopSize.width, height: session.desktopSize.height, startedAt: session.startedAt))
        }
    }

    public func sessionDidEnd(_ sessionId: UUID) {
        update { $0.sessions.removeAll { $0.id == sessionId } }
    }

    public func connectionDidFail(remoteAddress: String, reason: String) {
        update { $0.lastError = "\(remoteAddress): \(reason)" }
    }
}
