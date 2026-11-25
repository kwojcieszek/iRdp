import Foundation
import RdpProtocol

/// Network and protocol settings of the RDP server.
public struct RdpServerConfiguration: Sendable {
    public var host: String
    public var port: Int
    public var certificate: TlsCertificate
    public var maximumSessions: Int
    public var serverVersion: UInt32
    /// Name shown on the logon screen.
    public var serverName: String
    /// Use the RDP graphics pipeline (RDPGFX) when the client supports it.
    public var usesGraphicsPipeline: Bool
    /// Encode with hardware H.264 (AVC420) on the graphics pipeline when the client supports it.
    public var usesVideoEncoding: Bool
    /// Ignore credentials sent by the client (e.g. saved in Windows App) and always ask on the logon screen.
    public var alwaysShowsLogonScreen: Bool
    /// Initial streaming quality; change it later with `RdpServer.updateQuality(_:)`.
    public var quality: StreamingQuality

    public init(host: String = "0.0.0.0", port: Int = 3389, certificate: TlsCertificate, maximumSessions: Int = 1, serverVersion: UInt32 = RdpVersion.rdp10_0, serverName: String = ProcessInfo.processInfo.hostName, usesGraphicsPipeline: Bool = true, usesVideoEncoding: Bool = true, quality: StreamingQuality = StreamingQuality(), alwaysShowsLogonScreen: Bool = false) {
        self.host = host
        self.port = port
        self.certificate = certificate
        self.maximumSessions = maximumSessions
        self.serverVersion = serverVersion
        self.serverName = serverName
        self.usesGraphicsPipeline = usesGraphicsPipeline
        self.usesVideoEncoding = usesVideoEncoding
        self.quality = quality
        self.alwaysShowsLogonScreen = alwaysShowsLogonScreen
    }
}
