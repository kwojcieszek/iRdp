import Testing
@testable import RdpProtocol

struct SecurityTests {
    @Test func roundTripsClientInfo() throws {
        let info = ClientInfoPacket(domain: "HOME", userName: "kamil", password: "secret ąę")
        let parsed = try ClientInfoPacket.parse(info.encode())
        #expect(parsed.userName == "kamil")
        #expect(parsed.domain == "HOME")
        #expect(parsed.password == "secret ąę")
        #expect(parsed.flags.contains(.unicode))
    }

    @Test func rejectsPacketsWithoutInfoFlag() {
        #expect(throws: RdpProtocolError.self) { try ClientInfoPacket.parse([0x00, 0x00, 0x00, 0x00]) }
    }

    @Test func encodesValidClientLicensePdu() {
        #expect(LicenseErrorMessage.validClient() == [0x80, 0x00, 0x00, 0x00, 0xFF, 0x03, 0x10, 0x00, 0x07, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x04, 0x00, 0x00, 0x00])
    }
}
