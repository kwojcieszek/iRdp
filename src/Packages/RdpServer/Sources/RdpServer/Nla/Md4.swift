/// MD4 (RFC 1320), needed only for NTLM's NT hash.
enum Md4 {
    static func hash(_ message: [UInt8]) -> [UInt8] {
        var a: UInt32 = 0x6745_2301, b: UInt32 = 0xEFCD_AB89, c: UInt32 = 0x98BA_DCFE, d: UInt32 = 0x1032_5476
        var data = message
        let bitLength = UInt64(message.count) * 8
        data.append(0x80)
        while data.count % 64 != 56 { data.append(0) }
        for shift in stride(from: 0, to: 64, by: 8) { data.append(UInt8(truncatingIfNeeded: bitLength >> UInt64(shift))) }
        func f(_ x: UInt32, _ y: UInt32, _ z: UInt32) -> UInt32 { (x & y) | (~x & z) }
        func g(_ x: UInt32, _ y: UInt32, _ z: UInt32) -> UInt32 { (x & y) | (x & z) | (y & z) }
        func h(_ x: UInt32, _ y: UInt32, _ z: UInt32) -> UInt32 { x ^ y ^ z }
        func rotate(_ x: UInt32, _ s: UInt32) -> UInt32 { (x << s) | (x >> (32 - s)) }
        for chunk in stride(from: 0, to: data.count, by: 64) {
            var x = [UInt32](repeating: 0, count: 16)
            for i in 0..<16 {
                let o = chunk + i * 4
                x[i] = UInt32(data[o]) | UInt32(data[o + 1]) << 8 | UInt32(data[o + 2]) << 16 | UInt32(data[o + 3]) << 24
            }
            let (aa, bb, cc, dd) = (a, b, c, d)
            for i in [0, 4, 8, 12] {
                a = rotate(a &+ f(b, c, d) &+ x[i], 3)
                d = rotate(d &+ f(a, b, c) &+ x[i + 1], 7)
                c = rotate(c &+ f(d, a, b) &+ x[i + 2], 11)
                b = rotate(b &+ f(c, d, a) &+ x[i + 3], 19)
            }
            for i in [0, 1, 2, 3] {
                a = rotate(a &+ g(b, c, d) &+ x[i] &+ 0x5A82_7999, 3)
                d = rotate(d &+ g(a, b, c) &+ x[i + 4] &+ 0x5A82_7999, 5)
                c = rotate(c &+ g(d, a, b) &+ x[i + 8] &+ 0x5A82_7999, 9)
                b = rotate(b &+ g(c, d, a) &+ x[i + 12] &+ 0x5A82_7999, 13)
            }
            for i in [0, 2, 1, 3] {
                a = rotate(a &+ h(b, c, d) &+ x[i] &+ 0x6ED9_EBA1, 3)
                d = rotate(d &+ h(a, b, c) &+ x[i + 8] &+ 0x6ED9_EBA1, 9)
                c = rotate(c &+ h(d, a, b) &+ x[i + 4] &+ 0x6ED9_EBA1, 11)
                b = rotate(b &+ h(c, d, a) &+ x[i + 12] &+ 0x6ED9_EBA1, 15)
            }
            a = a &+ aa; b = b &+ bb; c = c &+ cc; d = d &+ dd
        }
        var result: [UInt8] = []
        for word in [a, b, c, d] { for shift in stride(from: 0, to: 32, by: 8) { result.append(UInt8(truncatingIfNeeded: word >> UInt32(shift))) } }
        return result
    }
}
