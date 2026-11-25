import Testing
@testable import RdpProtocol

struct TransportTests {
    @Test func wrapsAndUnwrapsTpkt() throws {
        let packet = TpktPacket.wrap([0xAA, 0xBB])
        #expect(packet == [0x03, 0x00, 0x00, 0x06, 0xAA, 0xBB])
        #expect(try TpktPacket.unwrap(packet) == [0xAA, 0xBB])
    }

    @Test func rejectsTpktWithWrongLength() {
        #expect(throws: RdpProtocolError.self) { try TpktPacket.unwrap([0x03, 0x00, 0x00, 0x09, 0x00]) }
    }

    @Test func parsesConnectionRequestFromFreeRdp() throws {
        // Cookie "mstshash=user" and RDP_NEG_REQ requesting SSL | HYBRID | HYBRID_EX.
        let cookie = Array("Cookie: mstshash=user\r\n".utf8)
        let negotiation: [UInt8] = [0x01, 0x00, 0x08, 0x00, 0x0B, 0x00, 0x00, 0x00]
        let payload = [UInt8(6 + cookie.count + negotiation.count), 0xE0, 0, 0, 0, 0, 0] + cookie + negotiation
        let request = try X224ConnectionRequest.parse(payload)
        #expect(request.cookie == "mstshash=user")
        #expect(request.requestedProtocols == [.tls, .credSsp, .credSspWithEarlyUserAuthorization])
        #expect(request.hasNegotiationRequest)
    }

    @Test func parsesConnectionRequestWithoutNegotiation() throws {
        let request = try X224ConnectionRequest.parse([0x06, 0xE0, 0, 0, 0, 0, 0])
        #expect(request.requestedProtocols == .standardRdp)
        #expect(!request.hasNegotiationRequest)
    }

    @Test func roundTripsConnectionRequest() throws {
        let request = X224ConnectionRequest(cookie: "mstshash=a", requestedProtocols: [.tls])
        #expect(try X224ConnectionRequest.parse(request.encode()) == request)
    }

    @Test func encodesConnectionConfirmSelectingTls() throws {
        let confirm = X224ConnectionConfirm(outcome: .selected(.tls, flags: X224ConnectionConfirm.extendedClientDataSupported))
        #expect(confirm.encode() == [0x0E, 0xD0, 0x00, 0x00, 0x12, 0x34, 0x00, 0x02, 0x01, 0x08, 0x00, 0x01, 0x00, 0x00, 0x00])
        #expect(try X224ConnectionConfirm.parse(confirm.encode()) == confirm)
    }

    @Test func encodesNegotiationFailure() throws {
        let confirm = X224ConnectionConfirm(outcome: .failure(.sslRequiredByServer))
        #expect(try X224ConnectionConfirm.parse(confirm.encode()) == confirm)
    }

    @Test func wrapsX224Data() throws {
        let packet = X224DataTpdu.packet([0x7F])
        #expect(packet == [0x03, 0x00, 0x00, 0x08, 0x02, 0xF0, 0x80, 0x7F])
        #expect(try X224DataTpdu.payload(of: TpktPacket.unwrap(packet)) == [0x7F])
    }

    @Test func splitsTpktAndFastPathFrames() throws {
        #expect(try RdpFrameSplitter.frameLength(of: [0x03, 0x00]) == nil)
        let tpkt = try #require(try RdpFrameSplitter.frameLength(of: [0x03, 0x00, 0x01, 0x02]))
        #expect(tpkt.kind == .tpkt && tpkt.length == 0x0102)
        let short = try #require(try RdpFrameSplitter.frameLength(of: [0x04, 0x10]))
        #expect(short.kind == .fastPath && short.length == 0x10)
        #expect(try RdpFrameSplitter.frameLength(of: [0x04, 0x81]) == nil)
        let long = try #require(try RdpFrameSplitter.frameLength(of: [0x00, 0x81, 0x23]))
        #expect(long.kind == .fastPath && long.length == 0x123)
    }

    @Test func rejectsUnknownFrameHeaders() {
        #expect(throws: RdpProtocolError.self) { try RdpFrameSplitter.frameLength(of: [0x01, 0x05]) }
    }
}
