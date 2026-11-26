import NIOCore
import RdpProtocol

/// Splits server output into TPKT and fast-path frames for the test client.
struct TestFrameDecoder: ByteToMessageDecoder {
    typealias InboundOut = [UInt8]

    mutating func decode(context: ChannelHandlerContext, buffer: inout ByteBuffer) throws -> DecodingState {
        guard let (_, length) = try RdpFrameSplitter.frameLength(of: Array(buffer.readableBytesView.prefix(4))),
              buffer.readableBytes >= length, let bytes = buffer.readBytes(length: length) else { return .needMoreData }
        context.fireChannelRead(wrapInboundOut(bytes))
        return .continue
    }
}
