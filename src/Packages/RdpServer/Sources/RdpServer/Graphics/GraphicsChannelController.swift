import RdpProtocol

/// Drives the "drdynvc" static channel: DVC capabilities, opening the RDPGFX channel and decoding client RDPGFX PDUs.
struct GraphicsChannelController {
    static let staticChannelName = "drdynvc"
    static let graphicsChannelName = "Microsoft::Windows::RDS::Graphics"
    static let graphicsChannelId: UInt32 = 1

    enum State: Equatable {
        case idle
        case awaitingCapabilities
        case awaitingCreateResponse
        case open
        case failed
    }

    private(set) var state: State = .idle
    private var staticReassembler = StaticChannelReassembler()
    private var dynamicReassembler = DynamicChannelReassembler()

    /// Starts the DVC handshake.
    mutating func start() -> [GraphicsChannelEvent] {
        state = .awaitingCapabilities
        return [.sendDynamicChannelPdu(DynamicChannelPdu.capabilities(version: 1).encode())]
    }

    /// Handles one static channel chunk received from the client.
    mutating func receive(chunk: [UInt8]) throws -> [GraphicsChannelEvent] {
        guard let message = try staticReassembler.append(chunk) else { return [] }
        let pdu = try DynamicChannelPdu.parse(message)
        switch pdu {
        case .capabilities:
            guard state == .awaitingCapabilities else { return [] }
            state = .awaitingCreateResponse
            return [.sendDynamicChannelPdu(DynamicChannelPdu.createRequest(channelId: Self.graphicsChannelId, name: Self.graphicsChannelName).encode())]
        case .createResponse(let id, let status):
            guard id == Self.graphicsChannelId else { return [] }
            state = status >= 0 ? .open : .failed
            return status >= 0 ? [] : [.closed]
        case .close(let id):
            guard id == Self.graphicsChannelId else { return [] }
            state = .failed
            return [.closed]
        case .data, .dataFirst:
            guard let (id, data) = dynamicReassembler.append(pdu), id == Self.graphicsChannelId else { return [] }
            return try GraphicsClientPdu.parseAll(data).compactMap { graphicsPdu -> GraphicsChannelEvent? in
                switch graphicsPdu {
                case .capsAdvertise(let sets): .clientCapabilities(sets)
                case .frameAcknowledge(let depth, _, _): .frameAcknowledged(queueDepth: depth)
                case .cacheImportOffer: .cacheImportOffer
                case .other: nil
                }
            }
        case .createRequest:
            return []
        }
    }

    /// Wraps an RDPGFX message for the graphics channel into DVC PDUs.
    static func dynamicChannelPdus(forGraphicsMessage message: [UInt8]) -> [[UInt8]] {
        DynamicChannelPdu.fragments(channelId: graphicsChannelId, message: SegmentedData.wrap(message))
    }
}
