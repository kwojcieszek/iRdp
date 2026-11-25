import RdpProtocol

/// What the graphics channel controller asks the connection to do.
enum GraphicsChannelEvent: Equatable {
    /// Send this DVC PDU on the drdynvc static channel.
    case sendDynamicChannelPdu([UInt8])
    case clientCapabilities([GraphicsCapabilitySet])
    case frameAcknowledged(queueDepth: UInt32)
    case cacheImportOffer
    case closed
}
