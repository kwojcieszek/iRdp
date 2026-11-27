import Foundation
import RdpServer
import Synchronization

/// Delivers a tone in 10 ms buffers and records the format it was started with.
final class SineAudioSource: AudioSource {
    private let state = Mutex<(format: AudioStreamFormat?, task: Task<Void, Never>?, stopCount: Int)>((nil, nil, 0))

    var startedFormat: AudioStreamFormat? { state.withLock { $0.format } }
    var stopCount: Int { state.withLock { $0.stopCount } }

    func start(format: AudioStreamFormat, onSamples: @escaping @Sendable ([UInt8]) -> Void) async throws {
        let task = Task {
            let frames = format.sampleRate / 100
            var phase = 0.0
            while !Task.isCancelled {
                var bytes: [UInt8] = []
                bytes.reserveCapacity(frames * format.bytesPerFrame)
                for _ in 0..<frames {
                    let sample = Int16(sin(phase) * 8000)
                    phase += 2 * .pi * 440 / Double(format.sampleRate)
                    for _ in 0..<format.channels {
                        bytes.append(UInt8(truncatingIfNeeded: sample))
                        bytes.append(UInt8(truncatingIfNeeded: sample >> 8))
                    }
                }
                onSamples(bytes)
                try? await Task.sleep(for: .milliseconds(10))
            }
        }
        state.withLock { $0.format = format; $0.task = task }
    }

    func stop() async {
        state.withLock {
            $0.task?.cancel()
            $0.task = nil
            $0.stopCount += 1
        }
    }
}
