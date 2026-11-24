/// TS_SET_ERROR_INFO_PDU body telling the client why the session ends.
public struct SetErrorInfoPdu: Sendable, Equatable {
    public static let logoffByUser: UInt32 = 0x0000_000C
    public static let disconnectedByOtherConnection: UInt32 = 0x0000_0005
    public static let serverInsufficientPrivileges: UInt32 = 0x0000_0009
    public static let serverDeniedConnection: UInt32 = 0x0000_0007
    public static let rpcInitiatedDisconnect: UInt32 = 0x0000_0001

    public var errorInfo: UInt32

    public init(errorInfo: UInt32) {
        self.errorInfo = errorInfo
    }

    public func encode() -> [UInt8] {
        var writer = ByteWriter()
        writer.writeUInt32LE(errorInfo)
        return writer.bytes
    }
}
