/// RDPGFX command identifiers (MS-RDPEGFX 2.2.1.5).
public enum GraphicsCommand: UInt16, Sendable {
    case wireToSurface1 = 0x0001
    case wireToSurface2 = 0x0002
    case deleteEncodingContext = 0x0003
    case solidFill = 0x0004
    case surfaceToSurface = 0x0005
    case surfaceToCache = 0x0006
    case cacheToSurface = 0x0007
    case evictCacheEntry = 0x0008
    case createSurface = 0x0009
    case deleteSurface = 0x000A
    case startFrame = 0x000B
    case endFrame = 0x000C
    case frameAcknowledge = 0x000D
    case resetGraphics = 0x000E
    case mapSurfaceToOutput = 0x000F
    case cacheImportOffer = 0x0010
    case cacheImportReply = 0x0011
    case capsAdvertise = 0x0012
    case capsConfirm = 0x0013
    case mapSurfaceToWindow = 0x0015
    case qoeFrameAcknowledge = 0x0016
    case mapSurfaceToScaledOutput = 0x0017
    case mapSurfaceToScaledWindow = 0x0018
}
