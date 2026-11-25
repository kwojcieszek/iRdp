/// Distinguishes the two framings used on an RDP connection.
public enum RdpFrameKind: Sendable, Equatable {
    case tpkt
    case fastPath
}
