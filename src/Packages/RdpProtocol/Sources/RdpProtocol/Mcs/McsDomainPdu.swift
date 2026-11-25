/// PER encoded MCS domain PDUs exchanged after the connect sequence (T.125).
public enum McsDomainPdu: Sendable, Equatable {
    case erectDomainRequest
    case attachUserRequest
    case attachUserConfirm(result: UInt8, userId: UInt16)
    case channelJoinRequest(userId: UInt16, channelId: UInt16)
    case channelJoinConfirm(result: UInt8, userId: UInt16, requestedChannelId: UInt16, channelId: UInt16)
    case sendDataRequest(userId: UInt16, channelId: UInt16, data: [UInt8])
    case sendDataIndication(userId: UInt16, channelId: UInt16, data: [UInt8])
    case disconnectProviderUltimatum

    private enum Code: UInt8 {
        case erectDomainRequest = 1
        case disconnectProviderUltimatum = 8
        case attachUserRequest = 10
        case attachUserConfirm = 11
        case channelJoinRequest = 14
        case channelJoinConfirm = 15
        case sendDataRequest = 25
        case sendDataIndication = 26
    }

    public static func parse(_ payload: [UInt8]) throws -> McsDomainPdu {
        var reader = ByteReader(payload)
        let first = try reader.readUInt8()
        guard let code = Code(rawValue: first >> 2) else {
            throw RdpProtocolError.unsupported("MCS domain PDU \(first >> 2)")
        }
        switch code {
        case .erectDomainRequest:
            return .erectDomainRequest
        case .disconnectProviderUltimatum:
            return .disconnectProviderUltimatum
        case .attachUserRequest:
            return .attachUserRequest
        case .attachUserConfirm:
            let result = try reader.readUInt8()
            let userId = first & 0x02 != 0 ? try reader.readUInt16BE() + McsChannel.userIdBase : 0
            return .attachUserConfirm(result: result, userId: userId)
        case .channelJoinRequest:
            let userId = try reader.readUInt16BE() + McsChannel.userIdBase
            return .channelJoinRequest(userId: userId, channelId: try reader.readUInt16BE())
        case .channelJoinConfirm:
            let result = try reader.readUInt8()
            let userId = try reader.readUInt16BE() + McsChannel.userIdBase
            let requested = try reader.readUInt16BE()
            let channelId = first & 0x02 != 0 ? try reader.readUInt16BE() : requested
            return .channelJoinConfirm(result: result, userId: userId, requestedChannelId: requested, channelId: channelId)
        case .sendDataRequest, .sendDataIndication:
            let userId = try reader.readUInt16BE() + McsChannel.userIdBase
            let channelId = try reader.readUInt16BE()
            try reader.skip(1)
            let length = try PerEncoding.readLength(&reader)
            let data = try reader.readBytes(length)
            return code == .sendDataRequest
                ? .sendDataRequest(userId: userId, channelId: channelId, data: data)
                : .sendDataIndication(userId: userId, channelId: channelId, data: data)
        }
    }

    public func encode() -> [UInt8] {
        var writer = ByteWriter()
        switch self {
        case .erectDomainRequest:
            writer.writeBytes([Code.erectDomainRequest.rawValue << 2, 0x01, 0x00, 0x01, 0x00])
        case .disconnectProviderUltimatum:
            writer.writeBytes([0x21, 0x80])
        case .attachUserRequest:
            writer.writeUInt8(Code.attachUserRequest.rawValue << 2)
        case .attachUserConfirm(let result, let userId):
            writer.writeUInt8(Code.attachUserConfirm.rawValue << 2 | 0x02)
            writer.writeUInt8(result)
            writer.writeUInt16BE(userId - McsChannel.userIdBase)
        case .channelJoinRequest(let userId, let channelId):
            writer.writeUInt8(Code.channelJoinRequest.rawValue << 2)
            writer.writeUInt16BE(userId - McsChannel.userIdBase)
            writer.writeUInt16BE(channelId)
        case .channelJoinConfirm(let result, let userId, let requested, let channelId):
            writer.writeUInt8(Code.channelJoinConfirm.rawValue << 2 | 0x02)
            writer.writeUInt8(result)
            writer.writeUInt16BE(userId - McsChannel.userIdBase)
            writer.writeUInt16BE(requested)
            writer.writeUInt16BE(channelId)
        case .sendDataRequest(let userId, let channelId, let data), .sendDataIndication(let userId, let channelId, let data):
            let code: Code = if case .sendDataRequest = self { .sendDataRequest } else { .sendDataIndication }
            writer.writeUInt8(code.rawValue << 2)
            writer.writeUInt16BE(userId - McsChannel.userIdBase)
            writer.writeUInt16BE(channelId)
            writer.writeUInt8(0x70)
            writer.writeBytes(PerEncoding.length(data.count))
            writer.writeBytes(data)
        }
        return writer.bytes
    }
}
