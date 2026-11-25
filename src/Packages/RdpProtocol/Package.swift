// swift-tools-version: 6.4
import PackageDescription

/// RDP protocol data units: encoding and decoding, no I/O.
let package = Package(
    name: "RdpProtocol",
    platforms: [.macOS(.v15)],
    products: [.library(name: "RdpProtocol", targets: ["RdpProtocol"])],
    targets: [
        .target(name: "RdpProtocol"),
        .testTarget(name: "RdpProtocolTests", dependencies: ["RdpProtocol"]),
    ],
    swiftLanguageModes: [.v6]
)
