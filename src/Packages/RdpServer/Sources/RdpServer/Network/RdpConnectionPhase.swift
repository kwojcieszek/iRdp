/// Phases of the RDP connection sequence (MS-RDPBCGR 1.3.1.1).
enum RdpConnectionPhase: Equatable {
    case awaitingConnectionRequest
    case credSsp
    case awaitingConnectInitial
    case channelConnection
    case awaitingClientInfo
    case authenticating
    case awaitingConfirmActive
    case finalizing
    case active
    case closed
}
