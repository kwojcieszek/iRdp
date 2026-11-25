import Testing
@testable import RdpProtocol

struct ShareAndCapabilityTests {
    @Test func encodesSynchronizeDataPduLikeSpecificationExample() {
        // MS-RDPBCGR 4.1.13 Client Synchronize PDU share headers.
        let pdu = SharePdu.encodeData(type: .synchronize, shareId: 0x0001_03EA, source: 1007, body: SynchronizePdu(targetUser: 1002).encode())
        #expect(pdu == [0x16, 0x00, 0x17, 0x00, 0xEF, 0x03, 0xEA, 0x03, 0x01, 0x00, 0x00, 0x01, 0x08, 0x00, 0x1F, 0x00, 0x00, 0x00, 0x01, 0x00, 0xEA, 0x03])
    }

    @Test func parsesConcatenatedSharePdus() throws {
        let first = SharePdu.encodeData(type: .control, shareId: 1, source: 1007, body: ControlPdu(action: .cooperate).encode())
        let second = SharePdu.encodeData(type: .fontList, shareId: 1, source: 1007, body: FontListPdu.encode())
        let pdus = try SharePdu.parseAll(first + second)
        #expect(pdus.map(\.dataType) == [.control, .fontList])
        #expect(try ControlPdu.parse(pdus[0].body) == ControlPdu(action: .cooperate))
    }

    @Test func skipsFlowControlPdus() throws {
        let flow: [UInt8] = [0x00, 0x80, 0x41, 0x00, 0x00, 0x00, 0x00, 0x00]
        #expect(try SharePdu.parseAll(flow).isEmpty)
    }

    @Test func serverCapabilitySetsHaveSpecifiedLengths() {
        let sets = ServerCapabilities.make(desktopWidth: 1280, desktopHeight: 800, bitsPerPixel: 32)
        let lengths = Dictionary(uniqueKeysWithValues: sets.map { ($0.type, $0.encode().count) })
        #expect(lengths[CapabilitySetType.general] == 24)
        #expect(lengths[CapabilitySetType.bitmap] == 28)
        #expect(lengths[CapabilitySetType.order] == 88)
        #expect(lengths[CapabilitySetType.pointer] == 10)
        #expect(lengths[CapabilitySetType.input] == 88)
        #expect(lengths[CapabilitySetType.multifragmentUpdate] == 8)
    }

    @Test func roundTripsTypedCapabilities() throws {
        let general = GeneralCapability(extraFlags: GeneralCapability.fastPathOutputSupported)
        #expect(try GeneralCapability.parse(general.encode().body) == general)
        let bitmap = BitmapCapability(preferredBitsPerPixel: 24, desktopWidth: 1440, desktopHeight: 900)
        #expect(try BitmapCapability.parse(bitmap.encode().body) == bitmap)
        #expect(try InputCapability.parse(InputCapability.serverDefault.encode().body) == InputCapability.serverDefault)
        #expect(try MultifragmentUpdateCapability.parse(MultifragmentUpdateCapability(maxRequestSize: 65535).encode().body).maxRequestSize == 65535)
    }

    @Test func roundTripsDemandAndConfirmActive() throws {
        let sets = ServerCapabilities.make(desktopWidth: 800, desktopHeight: 600, bitsPerPixel: 16)
        let demand = DemandActivePdu(shareId: 0x0001_03EA, capabilities: sets)
        #expect(try DemandActivePdu.parse(demand.encode()) == demand)
        let confirm = ConfirmActivePdu(shareId: 0x0001_03EA, capabilities: sets)
        let parsed = try ConfirmActivePdu.parse(confirm.encode())
        #expect(parsed == confirm)
        let bitmap = try BitmapCapability.parse(#require(parsed.capability(CapabilitySetType.bitmap)).body)
        #expect(bitmap.preferredBitsPerPixel == 16 && bitmap.desktopWidth == 800)
    }

    @Test func parsesRefreshRectAndSuppressOutput() throws {
        let refresh = try RefreshRectPdu.parse([0x01, 0, 0, 0, 0x00, 0x00, 0x00, 0x00, 0x1F, 0x00, 0x0F, 0x00])
        #expect(refresh.areas == [InclusiveRectangle(left: 0, top: 0, right: 31, bottom: 15)])
        #expect(try SuppressOutputPdu.parse([0x00, 0, 0, 0]).allowDisplayUpdates == false)
    }
}
