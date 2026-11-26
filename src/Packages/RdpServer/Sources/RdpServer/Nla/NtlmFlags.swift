/// NTLM negotiate flags (MS-NLMP 2.2.2.5).
enum NtlmFlags {
    static let unicode: UInt32 = 0x0000_0001
    static let requestTarget: UInt32 = 0x0000_0004
    static let sign: UInt32 = 0x0000_0010
    static let seal: UInt32 = 0x0000_0020
    static let ntlm: UInt32 = 0x0000_0200
    static let alwaysSign: UInt32 = 0x0000_8000
    static let targetTypeServer: UInt32 = 0x0002_0000
    static let extendedSessionSecurity: UInt32 = 0x0008_0000
    static let targetInfo: UInt32 = 0x0080_0000
    static let version: UInt32 = 0x0200_0000
    static let bits128: UInt32 = 0x2000_0000
    static let keyExchange: UInt32 = 0x4000_0000
    static let bits56: UInt32 = 0x8000_0000

    /// Flags the server answers with, limited to what the client asked for.
    static func serverFlags(for client: UInt32) -> UInt32 {
        let supported = unicode | requestTarget | sign | seal | ntlm | alwaysSign | extendedSessionSecurity | targetInfo | version | bits128 | keyExchange | bits56
        return (client & supported) | unicode | ntlm | targetInfo | targetTypeServer | extendedSessionSecurity
    }
}
