/// Fast-path output update codes (MS-RDPBCGR 2.2.9.1.2.1).
public enum FastPathUpdateCode: UInt8, Sendable {
    case orders = 0x0
    case bitmap = 0x1
    case palette = 0x2
    case synchronize = 0x3
    case surfaceCommands = 0x4
    case hiddenPointer = 0x5
    case defaultPointer = 0x6
    case pointerPosition = 0x8
    case colorPointer = 0x9
    case cachedPointer = 0xA
    case newPointer = 0xB
    case largePointer = 0xC
}
