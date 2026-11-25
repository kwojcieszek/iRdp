/// Serializes reads from the frame stream.
actor FrameInbox {
    private var iterator: AsyncStream<[UInt8]>.Iterator

    init(stream: AsyncStream<[UInt8]>) {
        iterator = stream.makeAsyncIterator()
    }

    func next() async -> [UInt8]? {
        var current = iterator
        let frame = await current.next(isolation: self)
        iterator = current
        return frame
    }
}
