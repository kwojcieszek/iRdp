import NIOCore
import RdpProtocol

/// Splits the inbound byte stream into TPKT and fast-path frames.
struct RdpFrameDecoder: ByteToMessageDecoder {
    typealias InboundOut = RdpInboundFrame

    mutating func decode(context: ChannelHandlerContext, buffer: inout ByteBuffer) throws -> DecodingState {
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
