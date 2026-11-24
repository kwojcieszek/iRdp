/// RDP 6.0 planar bitmap codec with RLE (MS-RDPEGDI 2.2.2.5.1 and 3.1.9), used for 32 bpp bitmap updates.
public enum PlanarBitmapEncoder {
    /// Format header: RLE compressed, no alpha plane, no color loss.
    public static let formatHeader: UInt8 = 0x30

    /// Encodes BGRX pixels (rows top to bottom, `width` pixels each, tightly packed) into a planar stream.
    /// Scanlines are stored bottom-up as in all bitmap updates.
    public static func encode(bgrx pixels: [UInt8], width: Int, height: Int) -> [UInt8] {
        precondition(pixels.count >= width * height * 4, "pixel buffer too small")
        var output: [UInt8] = [formatHeader]
        output.reserveCapacity(width * height + 1)
        for channel in [2, 1, 0] {
            var plane = [UInt8](repeating: 0, count: width * height)
            for row in 0..<height {
                let sourceRow = height - 1 - row
                for column in 0..<width {
                    plane[row * width + column] = pixels[(sourceRow * width + column) * 4 + channel]
                }
            }
            encodePlane(plane, width: width, height: height, into: &output)
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
        var raw: [UInt8] = []
        var last: UInt8 = 0
        var index = 0
        while index < values.count {
            var run = 0
            while index + run < values.count, values[index + run] == last { run += 1 }
            if run >= 3 {
                emitSegment(raw: raw, run: run, repeating: last, into: &output)
                raw.removeAll(keepingCapacity: true)
                index += run
                continue
            }
            raw.append(values[index])
            last = values[index]
            index += 1
            if raw.count == 15 {
                emitSegment(raw: raw, run: 0, repeating: last, into: &output)
                raw.removeAll(keepingCapacity: true)
            }
        }
        if !raw.isEmpty { emitSegment(raw: raw, run: 0, repeating: last, into: &output) }
    }

    private static func emitSegment(raw: [UInt8], run: Int, repeating value: UInt8, into output: inout [UInt8]) {
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
