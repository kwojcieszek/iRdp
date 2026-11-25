/// Fast-path input PDU (TS_FP_INPUT_PDU, MS-RDPBCGR 2.2.8.1.2) without encryption.
public enum FastPathInputPdu {
    enum EventCode: UInt8 {
        case scancode = 0
        case mouse = 1
        case extendedMouse = 2
        case synchronize = 3
        case unicode = 4
        case relativeMouse = 5
        case qoeTimestamp = 6
    }

    public static func parse(_ frame: [UInt8]) throws -> [RdpInputEvent] {
        var reader = ByteReader(frame)
        let header = try reader.readUInt8()
        guard header & 0xC0 == 0 else { throw RdpProtocolError.unsupported("encrypted fast-path input") }
        var eventCount = Int((header >> 2) & 0x0F)
        let lengthByte = try reader.readUInt8()
        if lengthByte & 0x80 != 0 { try reader.skip(1) }
        if eventCount == 0 { eventCount = Int(try reader.readUInt8()) }
        var events: [RdpInputEvent] = []
        for _ in 0..<eventCount {
            let eventHeader = try reader.readUInt8()
            let flags = eventHeader & 0x1F
            guard let code = EventCode(rawValue: eventHeader >> 5) else {
                throw RdpProtocolError.unsupported("fast-path event \(eventHeader >> 5)")
            }
            switch code {
            case .scancode:
                let scancode = try reader.readUInt8()
                // EXTENDED1 prefixed scancodes (Pause/Break) have no macOS equivalent.
                guard flags & 0x04 == 0 else { continue }
                events.append(.keyboard(scancode: scancode, isExtended: flags & 0x02 != 0, isRelease: flags & 0x01 != 0))
            case .mouse:
                let pointer = PointerFlags(rawValue: try reader.readUInt16LE())
                events.append(.mouse(flags: pointer, x: try reader.readUInt16LE(), y: try reader.readUInt16LE()))
            case .extendedMouse:
                let pointer = ExtendedPointerFlags(rawValue: try reader.readUInt16LE())
                events.append(.extendedMouse(flags: pointer, x: try reader.readUInt16LE(), y: try reader.readUInt16LE()))
            case .synchronize:
                events.append(.synchronize(KeyboardToggleFlags(rawValue: UInt32(flags))))
            case .unicode:
                events.append(.unicodeKeyboard(codeUnit: try reader.readUInt16LE(), isRelease: flags & 0x01 != 0))
            case .relativeMouse:
                let pointer = PointerFlags(rawValue: try reader.readUInt16LE())
                events.append(.relativeMouse(flags: pointer, deltaX: try reader.readInt16LE(), deltaY: try reader.readInt16LE()))
            case .qoeTimestamp:
                try reader.skip(4)
            }
        }
        return events
    }

    /// Encodes events into a fast-path input PDU (used by clients and tests).
    public static func encode(_ events: [RdpInputEvent]) -> [UInt8] {
        var body = ByteWriter()
        for event in events {
            switch event {
            case .keyboard(let scancode, let isExtended, let isRelease):
                body.writeUInt8(EventCode.scancode.rawValue << 5 | (isExtended ? 0x02 : 0) | (isRelease ? 0x01 : 0))
                body.writeUInt8(scancode)
            case .mouse(let flags, let x, let y):
                body.writeUInt8(EventCode.mouse.rawValue << 5)
                body.writeUInt16LE(flags.rawValue)
                body.writeUInt16LE(x)
                body.writeUInt16LE(y)
            case .extendedMouse(let flags, let x, let y):
                body.writeUInt8(EventCode.extendedMouse.rawValue << 5)
                body.writeUInt16LE(flags.rawValue)
                body.writeUInt16LE(x)
                body.writeUInt16LE(y)
            case .synchronize(let toggles):
                body.writeUInt8(EventCode.synchronize.rawValue << 5 | UInt8(toggles.rawValue & 0x1F))
            case .unicodeKeyboard(let codeUnit, let isRelease):
                body.writeUInt8(EventCode.unicode.rawValue << 5 | (isRelease ? 0x01 : 0))
                body.writeUInt16LE(codeUnit)
            case .relativeMouse(let flags, let deltaX, let deltaY):
                body.writeUInt8(EventCode.relativeMouse.rawValue << 5)
                body.writeUInt16LE(flags.rawValue)
                body.writeInt16LE(deltaX)
                body.writeInt16LE(deltaY)
            }
        }
        let count = events.count
        let header: UInt8 = count < 16 ? UInt8(count) << 2 : 0
        let extra: [UInt8] = count < 16 ? [] : [UInt8(count)]
        return FastPathLength.frame(header: header, payload: extra + body.bytes)
    }
}
