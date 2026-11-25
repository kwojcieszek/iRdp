/// Converts BGRA pixels into the RDP uncompressed bitmap formats (32, 24 or 16 bits per pixel).
public enum PixelFormatConverter {
    public static func bytesPerPixel(for bitsPerPixel: Int) -> Int {
        switch bitsPerPixel {
        case 32: 4
        case 24: 3
        default: 2
        }
    }

    /// Appends `count` pixels from `source` (BGRA) in the given format.
    public static func appendRow(from source: UnsafeRawBufferPointer, offset: Int, count: Int, bitsPerPixel: Int, to destination: inout [UInt8]) {
        switch bitsPerPixel {
        case 32:
            for index in 0..<count {
                let base = offset + index * 4
                destination.append(source[base])
                destination.append(source[base + 1])
                destination.append(source[base + 2])
                destination.append(0xFF)
            }
        case 24:
            for index in 0..<count {
                let base = offset + index * 4
                destination.append(source[base])
                destination.append(source[base + 1])
                destination.append(source[base + 2])
            }
        default:
            for index in 0..<count {
                let base = offset + index * 4
                let blue = UInt16(source[base]) >> 3
                let green = UInt16(source[base + 1]) >> 2
                let red = UInt16(source[base + 2]) >> 3
                let value = red << 11 | green << 5 | blue
                destination.append(UInt8(truncatingIfNeeded: value))
                destination.append(UInt8(truncatingIfNeeded: value >> 8))
            }
        }
    }
}
