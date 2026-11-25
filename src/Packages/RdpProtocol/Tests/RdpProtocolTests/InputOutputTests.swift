import Testing
@testable import RdpProtocol

struct InputOutputTests {
    @Test func roundTripsFastPathInputEvents() throws {
        let events: [RdpInputEvent] = [
            .keyboard(scancode: 0x1E, isExtended: false, isRelease: false),
            .keyboard(scancode: 0x48, isExtended: true, isRelease: true),
            .mouse(flags: [.move], x: 100, y: 200),
            .mouse(flags: [.down, .button1], x: 100, y: 200),
            .extendedMouse(flags: [.down, .xButton1], x: 1, y: 2),
            .unicodeKeyboard(codeUnit: 0x0105, isRelease: false),
            .relativeMouse(flags: [.move], deltaX: -5, deltaY: 7),
            .synchronize([.capsLock, .numLock]),
        ]
        #expect(try FastPathInputPdu.parse(FastPathInputPdu.encode(events)) == events)
    }

    @Test func parsesFastPathPduWithMoreThanFifteenEvents() throws {
        let events = (0..<20).map { RdpInputEvent.keyboard(scancode: UInt8($0 + 2), isExtended: false, isRelease: false) }
        #expect(try FastPathInputPdu.parse(FastPathInputPdu.encode(events)) == events)
    }

    @Test func skipsPauseKeyPrefix() throws {
        // Header (1 event), length 4, event with EXTENDED1 flag.
        #expect(try FastPathInputPdu.parse([0x04, 0x04, 0x04, 0x1D]).isEmpty)
    }

    @Test func decodesWheelRotation() {
        #expect(PointerFlags(rawValue: 0x0278).wheelRotation == 120)
        #expect(PointerFlags(rawValue: 0x0388).wheelRotation == -120)
    }

    @Test func parsesSlowPathInput() throws {
        var writer = ByteWriter()
        writer.writeUInt16LE(2)
        writer.writeUInt16LE(0)
        writer.writeUInt32LE(0)
        writer.writeUInt16LE(0x0004)
        writer.writeUInt16LE(0x8000)
        writer.writeUInt16LE(0x1E)
        writer.writeUInt16LE(0)
        writer.writeUInt32LE(0)
        writer.writeUInt16LE(0x8001)
        writer.writeUInt16LE(0x0800)
        writer.writeUInt16LE(10)
        writer.writeUInt16LE(20)
        #expect(try SlowPathInputPdu.parse(writer.bytes) == [.keyboard(scancode: 0x1E, isExtended: false, isRelease: true), .mouse(flags: [.move], x: 10, y: 20)])
    }

    @Test func encodesFastPathLengthInShortAndLongForm() {
        #expect(FastPathLength.frame(header: 0, payload: [1, 2]) == [0x00, 0x04, 1, 2])
        let long = FastPathLength.frame(header: 0, payload: [UInt8](repeating: 0, count: 200))
        #expect(Array(long.prefix(3)) == [0x00, 0x80, 203])
        #expect(long.count == 203)
    }

    @Test func roundTripsBitmapUpdatePdu() throws {
        let rectangle = BitmapRectangle(destLeft: 0, destTop: 0, destRight: 3, destBottom: 0, width: 4, height: 1, bitsPerPixel: 32, data: [UInt8](repeating: 7, count: 16))
        let pdu = FastPathUpdate.pdu([FastPathUpdate(code: .bitmap, data: BitmapUpdate(rectangles: [rectangle]).encode()), FastPathUpdate(code: .defaultPointer)])
        let updates = try FastPathUpdate.parsePdu(pdu)
        #expect(updates.map(\.code) == [.bitmap, .defaultPointer])
        #expect(try BitmapUpdate.parse(updates[0].data).rectangles == [rectangle])
    }
}
