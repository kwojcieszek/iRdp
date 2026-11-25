import NIOCore

/// Forwards decoded frames into an AsyncStream and finishes it when the connection closes.
final class FrameCollector: ChannelInboundHandler, Sendable {
    typealias InboundIn = [UInt8]

    private let continuation: AsyncStream<[UInt8]>.Continuation

    init(continuation: AsyncStream<[UInt8]>.Continuation) {
        self.continuation = continuation
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        continuation.yield(unwrapInboundIn(data))
    }

    func channelInactive(context: ChannelHandlerContext) {
        continuation.finish()
    }

    func errorCaught(context: ChannelHandlerContext, error: any Error) {
        continuation.finish()
        context.close(promise: nil)
    }
}
