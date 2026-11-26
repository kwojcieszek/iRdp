/// RDP 6.0 planar bitmap codec with RLE (MS-RDPEGDI 2.2.2.5.1 and 3.1.9), used for 32 bpp bitmap updates.
public enum PlanarBitmapEncoder {
    /// Format header: RLE compressed, no alpha plane, no color loss.
    public static let formatHeader: UInt8 = 0x30

    /// Encodes BGRX pixels (rows top to bottom, `width` pixels each, tightly packed) into a planar stream.
    /// Scanlines are stored bottom-up as in bitmap updates, or top-down for the graphics pipeline.
    public static func encode(bgrx pixels: [UInt8], width: Int, height: Int, topDown: Bool = false) -> [UInt8] {
        precondition(pixels.count >= width * height * 4, "pixel buffer too small")
        return pixels.withUnsafeBytes { encode(source: $0, bytesPerRow: width * 4, left: 0, top: 0, width: width, height: height, topDown: topDown) }
    }

    /// Encodes a rectangle of a BGRX image directly from its buffer, without copying the pixels first.
    public static func encode(source: UnsafeRawBufferPointer, bytesPerRow: Int, left: Int, top: Int, width: Int, height: Int, topDown: Bool) -> [UInt8] {
        var output: [UInt8] = [formatHeader]
        output.reserveCapacity(width * height + 64)
        guard let base = source.baseAddress?.assumingMemoryBound(to: UInt8.self), width > 0, height > 0 else { return output }
        var previous = [UInt8](repeating: 0, count: width)
        var line = [UInt8](repeating: 0, count: width)
        for channel in [2, 1, 0] {
            for row in 0..<height {
                let sourceRow = topDown ? top + row : top + height - 1 - row
                let rowStart = base + sourceRow * bytesPerRow + left * 4 + channel
                previous.withUnsafeMutableBufferPointer { previousValues in
                    line.withUnsafeMutableBufferPointer { values in
                        for column in 0..<width {
                            let value = rowStart[column * 4]
                            if row == 0 {
                                values[column] = value
                            } else {
                                let delta = Int8(truncatingIfNeeded: Int(value) &- Int(previousValues[column]))
                                values[column] = delta >= 0 ? UInt8(delta) &* 2 : UInt8(truncatingIfNeeded: -Int(delta) * 2 - 1)
                            }
                            previousValues[column] = value
                        }
                    }
                }
                encodeScanline(line, into: &output)
            }
        }
        return output
    }

    static func encodePlane(_ plane: [UInt8], width: Int, height: Int, into output: inout [UInt8]) {
        var line = [UInt8](repeating: 0, count: width)
        for row in 0..<height {
            let start = row * width
            if row == 0 {
                for column in 0..<width { line[column] = plane[start + column] }
            } else {
                for column in 0..<width {
                    let delta = Int(plane[start + column]) - Int(plane[start - width + column])
                    let wrapped = Int(Int8(truncatingIfNeeded: delta))
                    line[column] = UInt8(truncatingIfNeeded: wrapped >= 0 ? wrapped * 2 : -wrapped * 2 - 1)
                }
            }
            encodeScanline(line, into: &output)
        }
    }

    /// Encodes one scanline as RDP6_RLE_SEGMENTS. A run repeats the previous value of the scanline (initially zero).
    static func encodeScanline(_ values: [UInt8], into output: inout [UInt8]) {
        values.withUnsafeBufferPointer { values in
            var rawStart = 0
            var rawCount = 0
            var last: UInt8 = 0
            var index = 0
            let count = values.count
            while index < count {
                var run = 0
                while index + run < count, values[index + run] == last { run += 1 }
                if run >= 3 {
                    emitSegment(raw: values[rawStart..<rawStart + rawCount], run: run, repeating: last, into: &output)
                    rawCount = 0
                    index += run
                    rawStart = index
                    continue
                }
                if rawCount == 0 { rawStart = index }
                last = values[index]
                rawCount += 1
                index += 1
                if rawCount == 15 {
                    emitSegment(raw: values[rawStart..<rawStart + rawCount], run: 0, repeating: last, into: &output)
                    rawCount = 0
                    rawStart = index
                }
            }
            if rawCount > 0 { emitSegment(raw: values[rawStart..<rawStart + rawCount], run: 0, repeating: last, into: &output) }
        }
    }

    private static func emitSegment(raw: Slice<UnsafeBufferPointer<UInt8>>, run: Int, repeating value: UInt8, into output: inout [UInt8]) {
        let firstRun = run >= 3 ? min(run, 15) : 0
        if !raw.isEmpty || firstRun > 0 {
            output.append(UInt8(raw.count << 4 | firstRun))
            output.append(contentsOf: raw)
        }
        var remaining = run - firstRun
        while remaining > 0 {
            if remaining >= 16 {
                let chunk = min(remaining, 47)
                output.append(chunk >= 32 ? UInt8((chunk - 32) << 4 | 2) : UInt8((chunk - 16) << 4 | 1))
                remaining -= chunk
            } else if remaining >= 3 {
                output.append(UInt8(remaining))
                remaining = 0
            } else {
                output.append(UInt8(remaining << 4))
                output.append(contentsOf: repeatElement(value, count: remaining))
                remaining = 0
            }
        }
    }
}
