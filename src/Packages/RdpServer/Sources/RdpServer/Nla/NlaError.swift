/// Failures of network level authentication.
enum NlaError: Error, Equatable, CustomStringConvertible {
    case malformed(String)
    case unsupported(String)
    case logonFailure
    case integrity(String)

    var description: String {
        switch self {
        case .malformed(let what): "malformed \(what)"
        case .unsupported(let what): "unsupported \(what)"
        case .logonFailure: "wrong user name or password"
        case .integrity(let what): "integrity check failed: \(what)"
        }
    }
}
