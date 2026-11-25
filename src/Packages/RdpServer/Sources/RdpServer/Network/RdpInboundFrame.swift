import RdpProtocol

/// A complete frame read from the connection.
struct RdpInboundFrame: Sendable {
    var kind: RdpFrameKind
    var bytes: [UInt8]
}
