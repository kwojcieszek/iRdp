import Testing
@testable import RdpProtocol

struct BerEncodingTests {
    @Test func encodesLengthsInShortAndLongForm() {
        #expect(BerEncoder.length(0x7F) == [0x7F])
        #expect(BerEncoder.length(0x80) == [0x81, 0x80])
        #expect(BerEncoder.length(0x1234) == [0x82, 0x12, 0x34])
    }

    @Test func encodesIntegersWithMinimalLength() {
        #expect(BerEncoder.integer(0) == [0x02, 0x01, 0x00])
        #expect(BerEncoder.integer(34) == [0x02, 0x01, 0x22])
        #expect(BerEncoder.integer(0xFFF8) == [0x02, 0x03, 0x00, 0xFF, 0xF8])
    }

    @Test func roundTripsPrimitiveValues() throws {
        let bytes = BerEncoder.integer(65528) + BerEncoder.enumerated(3) + BerEncoder.boolean(true) + BerEncoder.octetString([1, 2, 3])
        var reader = BerReader(ByteReader(bytes))
        #expect(try reader.readInteger() == 65528)
        #expect(try reader.readEnumerated() == 3)
        #expect(try reader.readBoolean())
        #expect(try reader.readOctetString() == [1, 2, 3])
    }

    @Test func rejectsUnexpectedTags() {
        var reader = BerReader(ByteReader(BerEncoder.boolean(true)))
        #expect(throws: RdpProtocolError.self) { try reader.readInteger() }
    }

    @Test func encodesPerLengths() throws {
        #expect(PerEncoding.length(0x7F) == [0x7F])
        #expect(PerEncoding.length(0x1234) == [0x92, 0x34])
        var reader = ByteReader([0x92, 0x34, 0x05])
        #expect(try PerEncoding.readLength(&reader) == 0x1234)
        #expect(try PerEncoding.readLength(&reader) == 5)
    }
}
