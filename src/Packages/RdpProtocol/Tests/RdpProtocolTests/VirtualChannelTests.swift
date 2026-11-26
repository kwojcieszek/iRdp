import Testing
@testable import RdpProtocol

struct VirtualChannelTests {
    @Test func chunksAndReassemblesStaticChannelMessages() throws {
        let message = (0..<4000).map { UInt8(truncatingIfNeeded: $0) }
        let chunks = StaticChannelPdu.chunks(for: message, chunkLength: 1600)
        #expect(chunks.count == 3)
        var reassembler = StaticChannelReassembler()
        #expect(try reassembler.append(chunks[0]) == nil)
        #expect(try reassembler.append(chunks[1]) == nil)
        #expect(try reassembler.append(chunks[2]) == message)
    }

    @Test func singleChunkHasFirstAndLastFlags() throws {
        let chunk = StaticChannelPdu.chunks(for: [1, 2, 3])[0]
        #expect(chunk == [3, 0, 0, 0, 3, 0, 0, 0, 1, 2, 3])
    }

    @Test func roundTripsDynamicChannelPdus() throws {
        let pdus: [DynamicChannelPdu] = [
            .capabilities(version: 1),
            .createRequest(channelId: 1, name: "Microsoft::Windows::RDS::Graphics"),
            .createResponse(channelId: 1, status: 0),
            .data(channelId: 300, data: [9, 8, 7]),
            .dataFirst(channelId: 1, totalLength: 70000, data: [1]),
            .close(channelId: 1),
        ]
        for pdu in pdus {
            #expect(try DynamicChannelPdu.parse(pdu.encode()) == pdu)
        }
        #expect(DynamicChannelPdu.capabilities(version: 1).encode() == [0x50, 0x00, 0x01, 0x00])
    }

    @Test(arguments: [10, 1598, 1599, 5000, 100_000])
    func fragmentsLargeMessagesWithinPduLimit(size: Int) throws {
        let message = (0..<size).map { UInt8(truncatingIfNeeded: $0 * 7) }
        let fragments = DynamicChannelPdu.fragments(channelId: 1, message: message)
        #expect(fragments.allSatisfy { $0.count <= DynamicChannelPdu.maximumPduLength })
        var reassembler = DynamicChannelReassembler()
        var result: (channelId: UInt32, message: [UInt8])?
        for fragment in fragments { result = reassembler.append(try DynamicChannelPdu.parse(fragment)) ?? result }
        #expect(result?.channelId == 1)
        #expect(result?.message == message)
    }

    @Test(arguments: [100, 65535, 200_000])
    func wrapsSegmentedData(size: Int) throws {
        let message = (0..<size).map { UInt8(truncatingIfNeeded: $0) }
        let wrapped = SegmentedData.wrap(message)
        #expect(wrapped.first == (size <= 65535 ? 0xE0 : 0xE1))
        #expect(try SegmentedData.unwrap(wrapped) == message)
    }
}
