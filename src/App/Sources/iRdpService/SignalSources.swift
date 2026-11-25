import Dispatch

/// Keeps signal dispatch sources alive for the lifetime of the process.
enum SignalSources {
    nonisolated(unsafe) private static var sources: [any DispatchSourceSignal] = []

    static func retain(_ source: any DispatchSourceSignal) {
        sources.append(source)
    }
}
