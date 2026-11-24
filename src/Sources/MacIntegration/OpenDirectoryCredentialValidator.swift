import Foundation
import OpenDirectory

/// Verifies local macOS account passwords through Open Directory.
public struct OpenDirectoryCredentialValidator: Sendable {
    public init() {}

    /// Returns the account's short name when the password is correct.
    public func verify(userName: String, password: String) -> String? {
        guard !userName.isEmpty, !password.isEmpty else { return nil }
        do {
            let node = try ODNode(session: ODSession.default(), type: ODNodeType(kODNodeTypeAuthentication))
            let record = try node.record(withRecordType: kODRecordTypeUsers, name: userName, attributes: nil)
            try record.verifyPassword(password)
            return record.recordName
        } catch {
            return nil
        }
    }
}
