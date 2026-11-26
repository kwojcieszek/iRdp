import RdpProtocol
import Testing
@testable import RdpServer

struct GraphicsChannelControllerTests {
    private func chunk(_ pdu: DynamicChannelPdu) -> [UInt8] {
        StaticChannelPdu.chunks(for: pdu.encode())[0]
    }

    @Test func opensGraphicsChannelAndDecodesClientPdus() throws {
        var controller = GraphicsChannelController()
        #expect(controller.start() == [.sendDynamicChannelPdu(DynamicChannelPdu.capabilities(version: 1).encode())])
        let create = try controller.receive(chunk: chunk(.capabilities(version: 3)))
        #expect(create == [.sendDynamicChannelPdu(DynamicChannelPdu.createRequest(channelId: 1, name: GraphicsChannelController.graphicsChannelName).encode())])
        #expect(try controller.receive(chunk: chunk(.createResponse(channelId: 1, status: 0))).isEmpty)
        #expect(controller.state == .open)
        let sets = [GraphicsCapabilitySet(version: GraphicsCapabilitySet.version107, flags: 0)]
        let events = try controller.receive(chunk: chunk(.data(channelId: 1, data: GraphicsClientPdu.capsAdvertise(sets).encode())))
        #expect(events == [.clientCapabilities(sets)])
        let ack = try controller.receive(chunk: chunk(.data(channelId: 1, data: GraphicsClientPdu.frameAcknowledge(queueDepth: 0, frameId: 1, totalFramesDecoded: 1).encode())))
        #expect(ack == [.frameAcknowledged(queueDepth: 0)])
    }

    @Test func reportsRefusedChannel() throws {
        var controller = GraphicsChannelController()
        _ = controller.start()
        _ = try controller.receive(chunk: chunk(.capabilities(version: 1)))
        #expect(try controller.receive(chunk: chunk(.createResponse(channelId: 1, status: -1))) == [.closed])
        #expect(controller.state == .failed)
    }
}
