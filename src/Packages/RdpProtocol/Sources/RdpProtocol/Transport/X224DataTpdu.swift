/// X.224 Data TPDU framing (`02 F0 80`) carried inside TPKT.
public enum X224DataTpdu {
    public static let header: [UInt8] = [0x02, X224TpduCode.data, 0x80]

    /// Wraps an MCS payload into a full TPKT + X.224 data packet.
    public static func packet(_ payload: [UInt8]) -> [UInt8] {
        TpktPacket.wrap(header + payload)
    }

    /// Returns the MCS payload of an X.224 data TPDU (TPKT payload as input).
    public static func payload(of tpktPayload: [UInt8]) throws -> [UInt8] {
        guard tpktPayload.count >= 3, tpktPayload[1] & 0xF0 == X224TpduCode.data else {
            throw RdpProtocolError.invalidValue("not an X.224 data TPDU")
        }
        let headerLength = Int(tpktPayload[0]) + 1
        return Array(tpktPayload[headerLength...])
    }
}
