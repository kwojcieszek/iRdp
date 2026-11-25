/// X.224 Connection Confirm PDU carrying an RDP Negotiation Response or Failure (MS-RDPBCGR 2.2.1.2).
public struct X224ConnectionConfirm: Sendable, Equatable {
    public enum Outcome: Sendable, Equatable {
        case selected(SecurityProtocols, flags: UInt8)
        case failure(NegotiationFailureCode)
        case noNegotiation
    }

    /// Server negotiation flags.
    public static let extendedClientDataSupported: UInt8 = 0x01
    public static let dynamicVirtualChannelGraphicsSupported: UInt8 = 0x02
    public static let restrictedAdminModeSupported: UInt8 = 0x08

    public var outcome: Outcome

    public init(outcome: Outcome) {
        self.outcome = outcome
    }

    public func encode() -> [UInt8] {
        var negotiation = ByteWriter()
        switch outcome {
        case .selected(let protocols, let flags):
            negotiation.writeUInt8(0x02)
            negotiation.writeUInt8(flags)
            negotiation.writeUInt16LE(8)
            negotiation.writeUInt32LE(protocols.rawValue)
        case .failure(let code):
            negotiation.writeUInt8(0x03)
            negotiation.writeUInt8(0)
            negotiation.writeUInt16LE(8)
            negotiation.writeUInt32LE(code.rawValue)
        case .noNegotiation:
            break
        }
        let variable = negotiation.bytes
        return [UInt8(6 + variable.count), X224TpduCode.connectionConfirm, 0, 0, 0x12, 0x34, 0] + variable
    }

    public static func parse(_ payload: [UInt8]) throws -> X224ConnectionConfirm {
        var reader = ByteReader(payload)
        let lengthIndicator = Int(try reader.readUInt8())
        guard try reader.readUInt8() & 0xF0 == X224TpduCode.connectionConfirm else {
            throw RdpProtocolError.invalidValue("not an X.224 connection confirm")
        }
        try reader.skip(5)
        guard lengthIndicator >= 14, reader.remaining >= 8 else { return X224ConnectionConfirm(outcome: .noNegotiation) }
        let type = try reader.readUInt8()
        let flags = try reader.readUInt8()
        _ = try reader.readUInt16LE()
        let value = try reader.readUInt32LE()
        switch type {
        case 0x02:
            return X224ConnectionConfirm(outcome: .selected(SecurityProtocols(rawValue: value), flags: flags))
        case 0x03:
            guard let code = NegotiationFailureCode(rawValue: value) else { throw RdpProtocolError.invalidValue("failure code \(value)") }
            return X224ConnectionConfirm(outcome: .failure(code))
        default:
            throw RdpProtocolError.invalidValue("negotiation type \(type)")
        }
    }
}
