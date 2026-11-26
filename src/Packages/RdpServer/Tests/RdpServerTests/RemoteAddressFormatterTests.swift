import Testing
@testable import RdpServer

struct RemoteAddressFormatterTests {
    @Test func stripsIPv4MappedPrefix() {
        #expect(RemoteAddressFormatter.plainIPv4("::ffff:192.168.1.20") == "192.168.1.20")
        #expect(RemoteAddressFormatter.plainIPv4("192.168.1.20") == "192.168.1.20")
        #expect(RemoteAddressFormatter.plainIPv4("fe80::1") == "fe80::1")
    }
}
