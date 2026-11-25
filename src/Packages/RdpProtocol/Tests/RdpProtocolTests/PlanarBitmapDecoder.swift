@testable import RdpProtocol

/// Reference decoder following MS-RDPEGDI 3.1.9 (and FreeRDP's implementation) to verify the encoder.
enum PlanarBitmapDecoder {
    /// Returns BGRX pixels with rows top to bottom.
    static func decode(_ data: [UInt8], width: Int, height: Int) throws -> [UInt8] {
        var reader = ByteReader(data)
        guard try reader.readUInt8() == PlanarBitmapEncoder.formatHeader else { throw RdpProtocolError.invalidValue("header") }
        var planes: [[UInt8]] = []
        for _ in 0..<3 { planes.append(try decodePlane(&reader, width: width, height: height)) }
        guard reader.isAtEnd else { throw RdpProtocolError.invalidValue("trailing bytes") }
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        for row in 0..<height {
            let target = height - 1 - row
            for column in 0..<width {
                let base = (target * width + column) * 4
                pixels[base + 2] = planes[0][row * width + column]
                pixels[base + 1] = planes[1][row * width + column]
                pixels[base] = planes[2][row * width + column]
                pixels[base + 3] = 0xFF
            }
        }
        return pixels
    }

    private static func decodePlane(_ reader: inout ByteReader, width: Int, height: Int) throws -> [UInt8] {
        var plane = [UInt8](repeating: 0, count: width * height)
        for row in 0..<height {
            var column = 0
            var pixel = 0
            while column < width {
                let control = try reader.readUInt8()
                var run = Int(control & 0x0F)
                var rawCount = Int(control >> 4)
                if run == 1 { run = rawCount + 16; rawCount = 0 } else if run == 2 { run = rawCount + 32; rawCount = 0 }
                guard column + rawCount + run <= width else { throw RdpProtocolError.invalidValue("segment overflows scanline") }
                for _ in 0..<rawCount {
                    let value = Int(try reader.readUInt8())
                    if row == 0 {
                        pixel = value
                    } else {
                        pixel = value & 1 != 0 ? -((value >> 1) + 1) : value >> 1
                    }
                    plane[row * width + column] = row == 0 ? UInt8(pixel) : UInt8(truncatingIfNeeded: Int(plane[(row - 1) * width + column]) + pixel)
                    column += 1
                }
                for _ in 0..<run {
                    plane[row * width + column] = row == 0 ? UInt8(truncatingIfNeeded: pixel) : UInt8(truncatingIfNeeded: Int(plane[(row - 1) * width + column]) + pixel)
                    column += 1
                }
            }
        }
        return plane
    }
}
