import NIOCore
import RdpProtocol

/// Splits the inbound byte stream into TPKT and fast-path frames.
struct RdpFrameDecoder: ByteToMessageDecoder {
    typealias InboundOut = RdpInboundFrame

    let framing: RdpFramingState

    mutating func decode(context: ChannelHandlerContext, buffer: inout ByteBuffer) throws -> DecodingState {
        if framing.expectsCredSsp {
            let prefix = Array(buffer.readableBytesView.prefix(6))
            guard prefix.first == 0x30 || prefix.isEmpty else { throw RdpProtocolError.invalidValue("expected a CredSSP message") }
            guard let length = DerNode.elementLength(of: prefix), length <= 1 << 20 else { return .needMoreData }
            guard buffer.readableBytes >= length, let bytes = buffer.readBytes(length: length) else { return .needMoreData }
            context.fireChannelRead(wrapInboundOut(RdpInboundFrame(kind: .credSsp, bytes: bytes)))
            return .continue
        }
        let prefix = Array(buffer.readableBytesView.prefix(4))
        guard let (kind, length) = try RdpFrameSplitter.frameLength(of: prefix) else { return .needMoreData }
        guard length >= 2 else { throw RdpProtocolError.invalidValue("frame length \(length)") }
        guard buffer.readableBytes >= length, let bytes = buffer.readBytes(length: length) else { return .needMoreData }
        context.fireChannelRead(wrapInboundOut(RdpInboundFrame(kind: kind, bytes: bytes)))
        return .continue
    }

    mutating func decodeLast(context: ChannelHandlerContext, buffer: inout ByteBuffer, seenEOF: Bool) throws -> DecodingState {
        .needMoreData
    }
}
