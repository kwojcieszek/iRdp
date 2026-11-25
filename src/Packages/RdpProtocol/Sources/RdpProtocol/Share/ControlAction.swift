/// Actions of TS_CONTROL_PDU.
public enum ControlAction: UInt16, Sendable {
    case requestControl = 1
    case grantedControl = 2
    case detach = 3
    case cooperate = 4
}
