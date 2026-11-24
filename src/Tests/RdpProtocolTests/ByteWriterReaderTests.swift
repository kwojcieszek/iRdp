import Testing
@testable import RdpProtocol

struct ByteWriterReaderTests {
    @Test func writesAndReadsIntegersInBothByteOrders() throws {
        var writer = ByteWriter()
        writer.writeUInt8(0xAB)
        writer.writeUInt16LE(0x1234)
        writer.writeUInt16BE(0x1234)
        writer.writeUInt32LE(0xDEAD_BEEF)
        writer.writeUInt32BE(0xDEAD_BEEF)
        writer.writeInt16LE(-2)
        #expect(writer.bytes == [0xAB, 0x34, 0x12, 0x12, 0x34, 0xEF, 0xBE, 0xAD, 0xDE, 0xDE, 0xAD, 0xBE, 0xEF, 0xFE, 0xFF])

        var reader = ByteReader(writer.bytes)
        #expect(try reader.readUInt8() == 0xAB)
        #expect(try reader.readUInt16LE() == 0x1234)
        #expect(try reader.readUInt16BE() == 0x1234)
        #expect(try reader.readUInt32LE() == 0xDEAD_BEEF)
        #expect(try reader.readUInt32BE() == 0xDEAD_BEEF)
        #expect(try reader.readInt16LE() == -2)
        #expect(reader.isAtEnd)
    }

    @Test func throwsWhenInputIsTruncated() {
        var reader = ByteReader([0x01])
        #expect(throws: RdpProtocolError.truncated(needed: 2, available: 1)) { try reader.readUInt16LE() }
    }

    @Test func encodesFixedSizeUtf16Strings() throws {
        var writer = ByteWriter()
        writer.writeUTF16LE("AB", fixedByteCount: 8)
        #expect(writer.bytes == [0x41, 0, 0x42, 0, 0, 0, 0, 0])
        var reader = ByteReader(writer.bytes)
        #expect(try reader.readUTF16LE(byteCount: 8) == "AB")
    }

    @Test func truncatesLongFixedSizeStringsKeepingTerminator() {
        var writer = ByteWriter()
        writer.writeUTF16LE("ABCDEF", fixedByteCount: 6)
        #expect(writer.bytes == [0x41, 0, 0x42, 0, 0, 0])
    }

    @Test func patchesValuesInPlace() {
        var writer = ByteWriter()
        writer.writeZeros(4)
        writer.setUInt16LE(0x0102, at: 0)
        writer.setUInt16BE(0x0102, at: 2)
        #expect(writer.bytes == [0x02, 0x01, 0x01, 0x02])
    }
}
