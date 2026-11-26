/// Minimal DER reader for the CredSSP and SPNEGO structures.
struct DerNode {
    let tag: UInt8
    let content: [UInt8]
    /// The complete encoding (tag, length and content).
    let encoded: [UInt8]

    static func parse(_ bytes: [UInt8], at start: Int = 0) throws -> (DerNode, next: Int) {
        guard start + 2 <= bytes.count else { throw NlaError.malformed("DER header") }
        let tag = bytes[start]
        var index = start + 1
        var length = Int(bytes[index])
        index += 1
        if length & 0x80 != 0 {
            let count = length & 0x7F
            guard count <= 4, index + count <= bytes.count else { throw NlaError.malformed("DER length") }
            length = 0
            for _ in 0..<count { length = length << 8 | Int(bytes[index]); index += 1 }
        }
        guard index + length <= bytes.count else { throw NlaError.malformed("DER content") }
        return (DerNode(tag: tag, content: Array(bytes[index..<index + length]), encoded: Array(bytes[start..<index + length])), index + length)
    }

    /// Children of a constructed node.
    func children() throws -> [DerNode] {
        var nodes: [DerNode] = []
        var index = 0
        while index < content.count {
            let (node, next) = try DerNode.parse(content, at: index)
            nodes.append(node)
            index = next
        }
        return nodes
    }

    func child(tag: UInt8) throws -> DerNode? {
        try children().first { $0.tag == tag }
    }

    var integerValue: Int {
        content.reduce(0) { $0 << 8 | Int($1) }
    }

    /// Length of a complete DER element at the start of `bytes`, or nil when more bytes are needed.
    static func elementLength<C: Collection>(of bytes: C) -> Int? where C.Element == UInt8, C.Index == Int {
        let start = bytes.startIndex
        guard bytes.count >= 2 else { return nil }
        let first = Int(bytes[start + 1])
        guard first & 0x80 != 0 else { return 2 + first }
        let count = first & 0x7F
        guard bytes.count >= 2 + count else { return nil }
        var length = 0
        for offset in 0..<count { length = length << 8 | Int(bytes[start + 2 + offset]) }
        return 2 + count + length
    }
}
