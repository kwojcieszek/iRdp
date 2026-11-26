import Testing
@testable import RdpProtocol

struct McsGccTests {
    private func makeClientData() -> ClientConnectionData {
        ClientConnectionData(
            core: ClientCoreData(desktopWidth: 1920, desktopHeight: 1080, clientName: "WORKSTATION", earlyCapabilityFlags: ClientCoreData.wants32BitsPerPixelSession),
            network: ClientNetworkData(channels: [ChannelDefinition(name: "rdpdr"), ChannelDefinition(name: "cliprdr")])
        )
    }

    @Test func roundTripsConnectInitialWithClientData() throws {
        let clientData = makeClientData()
        let initial = McsConnectInitial(userData: GccConferenceCreateRequest.encode(clientData: clientData.encodeBlocks()))
        let parsed = try McsConnectInitial.parse(initial.encode())
        #expect(parsed.targetParameters == .clientTarget)
        let decoded = try ClientConnectionData.parse(GccConferenceCreateRequest.parse(parsed.userData))
        #expect(decoded.core.desktopWidth == 1920)
        #expect(decoded.core.desktopHeight == 1080)
        #expect(decoded.core.clientName == "WORKSTATION")
        #expect(decoded.core.earlyCapabilityFlags == ClientCoreData.wants32BitsPerPixelSession)
        #expect(decoded.core.serverSelectedProtocol == 1)
        #expect(decoded.network.channels.map(\.name) == ["rdpdr", "cliprdr"])
    }

    @Test func encodesGccRequestHeaderLikeMicrosoftClients() {
        let encoded = GccConferenceCreateRequest.encode(clientData: [0xAA])
        #expect(Array(encoded.prefix(7)) == [0x00, 0x05, 0x00, 0x14, 0x7C, 0x00, 0x01])
        #expect(Array(encoded[8..<20]) == [0x00, 0x08, 0x00, 0x10, 0x00, 0x01, 0xC0, 0x00, 0x44, 0x75, 0x63, 0x61])
        #expect(Int(encoded[7]) == encoded.count - 8)
    }

    @Test func roundTripsConnectResponseWithServerData() throws {
        let serverData = ServerConnectionData(clientRequestedProtocols: [.tls, .credSsp], staticChannelIds: [1004, 1005, 1006])
        let response = McsConnectResponse(userData: GccConferenceCreateResponse.encode(serverData: serverData.encodeBlocks()))
        let parsed = try McsConnectResponse.parse(response.encode())
        #expect(parsed.result == 0)
        #expect(parsed.domainParameters == .serverDefault)
        let decoded = try ServerConnectionData.parse(GccConferenceCreateResponse.parse(parsed.userData))
        #expect(decoded == serverData)
    }

    @Test func padsServerNetworkDataForOddChannelCounts() throws {
        let blocks = try DataBlock.parseAll(ServerConnectionData(clientRequestedProtocols: [.tls], staticChannelIds: [1004]).encodeBlocks())
        let network = try #require(blocks.first { $0.type == DataBlockType.serverNetwork })
        #expect(network.body == [0xEB, 0x03, 0x01, 0x00, 0xEC, 0x03, 0x00, 0x00])
    }

    @Test func encodesDomainPdusLikeT125() {
        #expect(McsDomainPdu.attachUserConfirm(result: 0, userId: 1007).encode() == [0x2E, 0x00, 0x00, 0x06])
        #expect(McsDomainPdu.channelJoinConfirm(result: 0, userId: 1007, requestedChannelId: 1003, channelId: 1003).encode() == [0x3E, 0x00, 0x00, 0x06, 0x03, 0xEB, 0x03, 0xEB])
        #expect(McsDomainPdu.disconnectProviderUltimatum.encode() == [0x21, 0x80])
    }

    @Test(arguments: [3, 200, 5000])
    func roundTripsSendDataPdus(size: Int) throws {
        let data = (0..<size).map { UInt8(truncatingIfNeeded: $0) }
        let request = McsDomainPdu.sendDataRequest(userId: 1007, channelId: 1003, data: data)
        #expect(try McsDomainPdu.parse(request.encode()) == request)
        let indication = McsDomainPdu.sendDataIndication(userId: 1007, channelId: 1003, data: data)
        #expect(try McsDomainPdu.parse(indication.encode()) == indication)
    }

    @Test func parsesClientDomainRequests() throws {
        #expect(try McsDomainPdu.parse([0x04, 0x01, 0x00, 0x01, 0x00]) == .erectDomainRequest)
        #expect(try McsDomainPdu.parse([0x28]) == .attachUserRequest)
        #expect(try McsDomainPdu.parse([0x38, 0x00, 0x06, 0x03, 0xEB]) == .channelJoinRequest(userId: 1007, channelId: 1003))
    }
}
