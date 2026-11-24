/// Client Info PDU content (TS_INFO_PACKET) carrying the user's credentials.
public struct ClientInfoPacket: Sendable, Equatable {
    public var codePage: UInt32
    public var flags: ClientInfoFlags
    public var domain: String
    public var userName: String
    public var password: String
    public var alternateShell: String
    public var workingDirectory: String

    public init(codePage: UInt32 = 0, flags: ClientInfoFlags = [.mouse, .unicode, .autoLogon, .disableControlAltDelete], domain: String = "", userName: String, password: String, alternateShell: String = "", workingDirectory: String = "") {
        self.codePage = codePage
        self.flags = flags
        self.domain = domain
        self.userName = userName
        self.password = password
        self.alternateShell = alternateShell
        self.workingDirectory = workingDirectory
    }

    /// Parses the data of the MCS send data request, starting with the basic security header.
    public static func parse(_ data: [UInt8]) throws -> ClientInfoPacket {
        var reader = ByteReader(data)
        let securityFlags = SecurityHeaderFlags(rawValue: try reader.readUInt16LE())
        _ = try reader.readUInt16LE()
        guard securityFlags.contains(.infoPacket) else { throw RdpProtocolError.invalidValue("not a client info PDU") }
        guard !securityFlags.contains(.encrypt) else { throw RdpProtocolError.unsupported("encrypted client info") }
        let codePage = try reader.readUInt32LE()
        let flags = ClientInfoFlags(rawValue: try reader.readUInt32LE())
        let lengths = try (0..<5).map { _ in Int(try reader.readUInt16LE()) }
        let isUnicode = flags.contains(.unicode)
        let terminator = isUnicode ? 2 : 1
        var fields: [String] = []
        for length in lengths {
            let value = isUnicode ? try reader.readUTF16LE(byteCount: length) : try reader.readASCII(byteCount: length)
            try reader.skip(min(terminator, reader.remaining))
            fields.append(value)
        }
        return ClientInfoPacket(codePage: codePage, flags: flags, domain: fields[0], userName: fields[1], password: fields[2], alternateShell: fields[3], workingDirectory: fields[4])
    }

    public func encode() -> [UInt8] {
        var writer = ByteWriter()
        writer.writeUInt16LE(SecurityHeaderFlags.infoPacket.rawValue)
        writer.writeUInt16LE(0)
        writer.writeUInt32LE(codePage)
        writer.writeUInt32LE(flags.union(.unicode).rawValue)
        let fields = [domain, userName, password, alternateShell, workingDirectory]
        fields.forEach { writer.writeUInt16LE(UInt16($0.utf16.count * 2)) }
        fields.forEach { writer.writeUTF16LE($0, nullTerminated: true) }
        return writer.bytes
    }
}
