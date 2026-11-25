/// Builds a fast-path frame: one header byte followed by a 1 or 2 byte length that includes the header.
public enum FastPathLength {
    public static let maximumFrameLength = 0x7FFF

    public static func frame(header: UInt8, payload: [UInt8]) -> [UInt8] {
        let shortTotal = payload.count + 2
        if shortTotal <= 0x7F {
            return [header, UInt8(shortTotal)] + payload
        }
        let total = payload.count + 3
        return [header, UInt8(0x80 | (total >> 8)), UInt8(truncatingIfNeeded: total)] + payload
    }
}
