import Foundation
import RdpProtocol

/// Network and protocol settings of the RDP server.
public struct RdpServerConfiguration: Sendable {
    public var host: String
    public var port: Int
    public var certificate: TlsCertificate
    public var preferredBitsPerPixel: Int
    public var maximumSessions: Int
    public var serverVersion: UInt32
    /// Name shown on the logon screen.
    public var serverName: String

    public init(host: String = "0.0.0.0", port: Int = 3389, certificate: TlsCertificate, preferredBitsPerPixel: Int = 32, maximumSessions: Int = 1, serverVersion: UInt32 = RdpVersion.rdp10_0, serverName: String = ProcessInfo.processInfo.hostName) {
        self.host = host
        self.port = port
        self.certificate = certificate
        self.preferredBitsPerPixel = preferredBitsPerPixel
        self.maximumSessions = maximumSessions
        self.serverVersion = serverVersion
        self.serverName = serverName
    }
}
