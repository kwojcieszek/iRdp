/// Failures of the test client.
enum RdpTestClientError: Error {
    case connectionClosed
    case unexpected(String)
}
