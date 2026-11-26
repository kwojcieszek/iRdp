/// X.224 Connection Request PDU with optional cookie and RDP Negotiation Request (MS-RDPBCGR 2.2.1.1).
public struct X224ConnectionRequest: Sendable, Equatable {
    public var cookie: String?
    public var requestedProtocols: SecurityProtocols
    public var negotiationFlags: UInt8
    public var hasNegotiationRequest: Bool

    public init(cookie: String? = nil, requestedProtocols: SecurityProtocols, negotiationFlags: UInt8 = 0, hasNegotiationRequest: Bool = true) {
        self.cookie = cookie
        self.requestedProtocols = requestedProtocols
        self.negotiationFlags = negotiationFlags
        self.hasNegotiationRequest = hasNegotiationRequest
    }

    /// Parses the TPKT payload of a connection request.
    public static func parse(_ payload: [UInt8]) throws -> X224ConnectionRequest {
        var reader = ByteReader(payload)
        let lengthIndicator = Int(try reader.readUInt8())
        guard lengthIndicator + 1 <= payload.count else { throw RdpProtocolError.truncated(needed: lengthIndicator + 1, available: payload.count) }
        guard try reader.readUInt8() & 0xF0 == X224TpduCode.connectionRequest else {
            throw RdpProtocolError.invalidValue("not an X.224 connection request")
        }
        try reader.skip(5)
        var variable = Array(payload[reader.offset..<(lengthIndicator + 1)])
        var cookie: String?
        if variable.starts(with: Array("Cookie: ".utf8)) {
            if let end = Self.indexOfLineEnd(in: variable) {
                let text = String(decoding: variable[8..<end], as: UTF8.self)
                cookie = text
                variable.removeFirst(end + 2)
            }
        }
        var request = X224ConnectionRequest(cookie: cookie, requestedProtocols: .standardRdp, hasNegotiationRequest: false)
        if variable.count >= 8, variable[0] == 0x01 {
            var negotiation = ByteReader(variable)
            try negotiation.skip(1)
            request.negotiationFlags = try negotiation.readUInt8()
            _ = try negotiation.readUInt16LE()
            request.requestedProtocols = SecurityProtocols(rawValue: try negotiation.readUInt32LE())
            request.hasNegotiationRequest = true
        }
        return request
    }

    private static func indexOfLineEnd(in bytes: [UInt8]) -> Int? {
        guard bytes.count >= 2 else { return nil }
        for index in 0..<(bytes.count - 1) where bytes[index] == 0x0D && bytes[index + 1] == 0x0A {
            return index
        }
        return nil
    }

    /// Encodes the TPKT payload (used by clients and tests).
    public func encode() -> [UInt8] {
        var variable: [UInt8] = []
        if let cookie {
            variable += Array("Cookie: \(cookie)\r\n".utf8)
        }
        if hasNegotiationRequest {
            var writer = ByteWriter()
            writer.writeUInt8(0x01)
            writer.writeUInt8(negotiationFlags)
            writer.writeUInt16LE(8)
            writer.writeUInt32LE(requestedProtocols.rawValue)
            variable += writer.bytes
        }
        return [UInt8(6 + variable.count), X224TpduCode.connectionRequest, 0, 0, 0, 0, 0] + variable
    }
}
