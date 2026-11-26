/// Share control PDU types (MS-RDPBCGR 2.2.8.1.1.1.1).
public enum ShareControlPduType: UInt16, Sendable {
    case demandActive = 0x1
    case confirmActive = 0x3
    case deactivateAll = 0x6
    case data = 0x7
    case serverRedirect = 0xA
}
