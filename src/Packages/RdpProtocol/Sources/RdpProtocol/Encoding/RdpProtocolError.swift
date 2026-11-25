/// Errors raised while encoding or decoding RDP protocol data units.
public enum RdpProtocolError: Error, Equatable, Sendable {
    case truncated(needed: Int, available: Int)
    case invalidValue(String)
    case unsupported(String)
}
