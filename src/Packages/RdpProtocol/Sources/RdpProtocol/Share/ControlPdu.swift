/// TS_CONTROL_PDU body.
public struct ControlPdu: Sendable, Equatable {
    public var action: ControlAction
    public var grantId: UInt16
    public var controlId: UInt32

    public init(action: ControlAction, grantId: UInt16 = 0, controlId: UInt32 = 0) {
        self.action = action
        self.grantId = grantId
        self.controlId = controlId
    }

    public func encode() -> [UInt8] {
        var writer = ByteWriter()
        writer.writeUInt16LE(action.rawValue)
        writer.writeUInt16LE(grantId)
        writer.writeUInt32LE(controlId)
        return writer.bytes
    }

    public static func parse(_ body: [UInt8]) throws -> ControlPdu {
        var reader = ByteReader(body)
        guard let action = ControlAction(rawValue: try reader.readUInt16LE()) else {
            throw RdpProtocolError.invalidValue("control action")
        }
        return ControlPdu(action: action, grantId: try reader.readUInt16LE(), controlId: try reader.readUInt32LE())
    }
}
