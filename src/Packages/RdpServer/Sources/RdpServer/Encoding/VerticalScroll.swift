import Foundation
import RdpProtocol

/// A verified full-width band from the last transmitted image. Source row = destination row + offset.
struct VerticalScroll {
    let top: Int
    let bottom: Int
    let offset: Int

    static func detect(_ frame: ScreenFrame, previous: ScreenFrame) -> Self? {
        guard frame.height >= 256, frame.width <= Int(Int16.max), frame.height <= Int(Int16.max) else { return nil }
        return frame.pixels.withUnsafeBytes { current in
            previous.pixels.withUnsafeBytes { old in
                func equal(_ y: Int, _ source: Int) -> Bool {
                    memcmp(current.baseAddress! + y * frame.bytesPerRow, old.baseAddress! + source * previous.bytesPerRow, frame.width * 4) == 0
                }
                var candidateBudget = 4
                for anchor in [frame.height / 2, frame.height / 4, frame.height * 3 / 4] where !equal(anchor, anchor) {
                    for distance in 1...min(128, frame.height / 4) {
                        for offset in [distance, -distance] where equal(anchor, anchor + offset) {
                            // Disambiguate repeated lines before extending and verifying the entire band.
                            let limit = min(frame.height, frame.height - offset)
                            let start = max(0, -offset)
                            guard anchor + 8 < limit, equal(anchor + 8, anchor + 8 + offset) else { continue }
                            guard candidateBudget > 0 else { return nil }
                            candidateBudget -= 1
                            var top = anchor, bottom = anchor + 1
                            while top > start && equal(top - 1, top - 1 + offset) { top -= 1 }
                            while bottom < limit && equal(bottom, bottom + offset) { bottom += 1 }
                            if bottom - top >= frame.height / 4 { return Self(top: top, bottom: bottom, offset: offset) }
                            break
                        }
                    }
                }
                return nil
            }
        }
    }

    func order(width: Int) -> [UInt8] {
        var writer = ByteWriter()
        writer.writeUInt16LE(1) // numberOrders
        writer.writeBytes([0x09, 0x02, 0x7f]) // STANDARD | TYPE_CHANGE, ScrBlt, all seven fields
        writer.writeUInt16LE(0)
        writer.writeUInt16LE(UInt16(top))
        writer.writeUInt16LE(UInt16(width))
        writer.writeUInt16LE(UInt16(bottom - top))
        writer.writeUInt8(0xcc) // SRCCOPY
        writer.writeUInt16LE(0)
        writer.writeUInt16LE(UInt16(top + offset))
        return FastPathUpdate.pdu([FastPathUpdate(code: .orders, data: writer.bytes)])
    }
}
