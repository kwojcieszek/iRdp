/// CHANNEL_DEF structure of the client network data (MS-RDPBCGR 2.2.1.3.4.1).
public struct ChannelDefinition: Sendable, Equatable {
    public var name: String
    public var options: UInt32

    public init(name: String, options: UInt32 = 0x8000_0000) {
        self.name = name
        self.options = options
    }
}
