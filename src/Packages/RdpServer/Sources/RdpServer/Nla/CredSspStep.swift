/// What the connection does after a CredSSP message.
enum CredSspStep: Equatable {
    /// Send this TSRequest and wait for the next one.
    case respond([UInt8])
    /// Authentication finished with these credentials.
    case completed(TsCredentials)
    /// Authentication failed; send the optional TSRequest with the error code, then close.
    case failed(reason: String, response: [UInt8]?)
}
