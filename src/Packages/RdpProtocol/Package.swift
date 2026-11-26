// swift-tools-version: 6.4
import PackageDescription

/// RDP protocol data units: encoding and decoding, no I/O.
let package = Package(
    name: "RdpProtocol",
    platforms: [.macOS(.v15)],
    products: [.library(name: "RdpProtocol", targets: ["RdpProtocol"])],
    targets: [
        // Encoding runs per pixel; keep it optimized even in Debug builds (e.g. when running from Xcode).
        .target(name: "RdpProtocol", swiftSettings: [.unsafeFlags(["-O"], .when(configuration: .debug))]),
        .testTarget(name: "RdpProtocolTests", dependencies: ["RdpProtocol"]),
    ],
    swiftLanguageModes: [.v6]
)
