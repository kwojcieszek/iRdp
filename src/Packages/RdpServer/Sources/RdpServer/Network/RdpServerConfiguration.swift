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
    /// Use the RDP graphics pipeline (RDPGFX) when the client supports it.
    public var usesGraphicsPipeline: Bool
    /// Encode with hardware H.264 (AVC420) on the graphics pipeline when the client supports it.
    public var usesVideoEncoding: Bool
    public var videoBitRate: Int
    public var framesPerSecond: Int

    public init(host: String = "0.0.0.0", port: Int = 3389, certificate: TlsCertificate, preferredBitsPerPixel: Int = 32, maximumSessions: Int = 1, serverVersion: UInt32 = RdpVersion.rdp10_0, serverName: String = ProcessInfo.processInfo.hostName, usesGraphicsPipeline: Bool = true, usesVideoEncoding: Bool = true, videoBitRate: Int = 12_000_000, framesPerSecond: Int = 30) {
        self.host = host
        self.port = port
        self.certificate = certificate
        self.preferredBitsPerPixel = preferredBitsPerPixel
        self.maximumSessions = maximumSessions
        self.serverVersion = serverVersion
        self.serverName = serverName
        self.usesGraphicsPipeline = usesGraphicsPipeline
        self.usesVideoEncoding = usesVideoEncoding
        self.videoBitRate = videoBitRate
        self.framesPerSecond = framesPerSecond
    }
}
