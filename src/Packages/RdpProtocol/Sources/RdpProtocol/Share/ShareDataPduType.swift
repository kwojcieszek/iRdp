/// Share data PDU types, the `pduType2` field (MS-RDPBCGR 2.2.8.1.1.1.2).
public enum ShareDataPduType: UInt8, Sendable {
    case update = 2
    case control = 20
    case pointer = 27
    case input = 28
    case synchronize = 31
    case refreshRect = 33
    case playSound = 34
    case suppressOutput = 35
    case shutdownRequest = 36
    case shutdownDenied = 37
    case saveSessionInfo = 38
    case fontList = 39
    case fontMap = 40
    case setKeyboardIndicators = 41
    case bitmapCachePersistentList = 43
    case bitmapCacheErrorPdu = 44
    case setKeyboardImeStatus = 45
    case offscreenCacheErrorPdu = 46
    case setErrorInfo = 47
    case drawNineGridErrorPdu = 48
    case drawGdiPlusErrorPdu = 49
    case arcStatus = 50
    case statusInfo = 54
    case monitorLayout = 55
}
