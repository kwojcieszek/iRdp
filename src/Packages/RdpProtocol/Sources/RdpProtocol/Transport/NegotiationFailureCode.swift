/// Failure codes of RDP_NEG_FAILURE (MS-RDPBCGR 2.2.1.2.2).
public enum NegotiationFailureCode: UInt32, Sendable {
    case sslRequiredByServer = 0x0000_0001
    case sslNotAllowedByServer = 0x0000_0002
    case sslCertificateNotOnServer = 0x0000_0003
    case inconsistentFlags = 0x0000_0004
    case hybridRequiredByServer = 0x0000_0005
    case sslWithUserAuthenticationRequiredByServer = 0x0000_0006
}
