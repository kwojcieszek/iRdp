import Dispatch
import Foundation
import IRdpServiceCore

// iRdpService: headless RDP server started by launchd (LaunchAgent) or by the iRdp menu bar app.
let runtime = ServiceRuntime()

for signalNumber in [SIGTERM, SIGINT] {
    signal(signalNumber, SIG_IGN)
    let source = DispatchSource.makeSignalSource(signal: signalNumber, queue: .main)
    source.setEventHandler {
        Task {
            await runtime.stop()
            exit(0)
        }
    }
    source.resume()
    SignalSources.retain(source)
}

Task {
    await runtime.run()
    exit(0)
}

dispatchMain()
