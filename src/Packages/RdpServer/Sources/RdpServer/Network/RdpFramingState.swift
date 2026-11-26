/// Tells the frame decoder whether CredSSP (DER) messages are expected instead of TPKT and fast-path frames.
/// Shared by the decoder and the connection handler, which both run on the channel's event loop.
final class RdpFramingState: @unchecked Sendable {
    var expectsCredSsp = false
}
