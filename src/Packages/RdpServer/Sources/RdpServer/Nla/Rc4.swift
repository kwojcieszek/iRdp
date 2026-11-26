/// RC4 stream cipher, required by NTLM sealing.
struct Rc4 {
    private var state: [UInt8]
    private var i: UInt8 = 0
    private var j: UInt8 = 0

    init(key: [UInt8]) {
        state = (0...255).map { UInt8($0) }
        var j: UInt8 = 0
        for i in 0..<256 {
            j = j &+ state[i] &+ key[i % key.count]
            state.swapAt(i, Int(j))
        }
    }

    mutating func process(_ data: [UInt8]) -> [UInt8] {
        data.map { byte in
            i = i &+ 1
            j = j &+ state[Int(i)]
            state.swapAt(Int(i), Int(j))
            return byte ^ state[Int(state[Int(i)] &+ state[Int(j)])]
        }
    }
}
