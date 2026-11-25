/// Slow-path input event PDU body (TS_INPUT_PDU_DATA, MS-RDPBCGR 2.2.8.1.1.3).
public enum SlowPathInputPdu {
    public static func parse(_ body: [UInt8]) throws -> [RdpInputEvent] {
        var reader = ByteReader(body)
        let count = Int(try reader.readUInt16LE())
        try reader.skip(2)
        var events: [RdpInputEvent] = []
        for _ in 0..<count {
            try reader.skip(4)
            let messageType = try reader.readUInt16LE()
            switch messageType {
            case 0x0000:
                try reader.skip(2)
                events.append(.synchronize(KeyboardToggleFlags(rawValue: try reader.readUInt32LE())))
            case 0x0004:
                let flags = try reader.readUInt16LE()
                let code = try reader.readUInt16LE()
                try reader.skip(2)
                events.append(.keyboard(scancode: UInt8(truncatingIfNeeded: code), isExtended: flags & 0x0100 != 0, isRelease: flags & 0x8000 != 0))
            case 0x0005:
                let flags = try reader.readUInt16LE()
                let code = try reader.readUInt16LE()
                try reader.skip(2)
                events.append(.unicodeKeyboard(codeUnit: code, isRelease: flags & 0x8000 != 0))
            case 0x8001:
                let flags = PointerFlags(rawValue: try reader.readUInt16LE())
                events.append(.mouse(flags: flags, x: try reader.readUInt16LE(), y: try reader.readUInt16LE()))
            case 0x8002:
                let flags = ExtendedPointerFlags(rawValue: try reader.readUInt16LE())
                events.append(.extendedMouse(flags: flags, x: try reader.readUInt16LE(), y: try reader.readUInt16LE()))
            default:
                try reader.skip(6)
            }
        }
        return events
    }
}
