/// Determines the size of the next RDP frame (TPKT or fast-path) at the head of a byte stream.
public enum RdpFrameSplitter {
    /// Returns the frame kind and total length, or `nil` when more bytes are needed to know.
    public static func frameLength<C: Collection>(of prefix: C) throws -> (kind: RdpFrameKind, length: Int)? where C.Element == UInt8, C.Index == Int {
        guard let first = prefix.first else { return nil }
        let start = prefix.startIndex
        if first == TpktPacket.version {
            guard prefix.count >= 4 else { return nil }
            let length = Int(prefix[start + 2]) << 8 | Int(prefix[start + 3])
            guard length >= 4 else { throw RdpProtocolError.invalidValue("TPKT length \(length)") }
            return (.tpkt, length)
        }
        guard first & 0x03 == 0 else { throw RdpProtocolError.invalidValue("unknown frame header 0x\(String(first, radix: 16))") }
        guard prefix.count >= 2 else { return nil }
        let second = prefix[start + 1]
        if second & 0x80 == 0 {
            return (.fastPath, Int(second))
        }
        guard prefix.count >= 3 else { return nil }
        return (.fastPath, Int(second & 0x7F) << 8 | Int(prefix[start + 2]))
    }
}
