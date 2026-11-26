/// The NTLM "NT hash" of a password: MD4 of its UTF-16LE encoding. It is password-equivalent and must be kept secret.
public enum NtHash {
    public static func of(password: String) -> [UInt8] {
        var bytes: [UInt8] = []
        for unit in password.utf16 {
            bytes.append(UInt8(truncatingIfNeeded: unit))
            bytes.append(UInt8(truncatingIfNeeded: unit >> 8))
        }
        return Md4.hash(bytes)
    }
}
