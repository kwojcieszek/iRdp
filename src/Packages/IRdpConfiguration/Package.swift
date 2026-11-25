// swift-tools-version: 6.4
import PackageDescription

/// Settings and status shared by the iRdp app and the service.
let package = Package(
    name: "IRdpConfiguration",
    platforms: [.macOS(.v15)],
    products: [.library(name: "IRdpConfiguration", targets: ["IRdpConfiguration"])],
    targets: [
        .target(name: "IRdpConfiguration"),
        .testTarget(name: "IRdpConfigurationTests", dependencies: ["IRdpConfiguration"]),
    ],
    swiftLanguageModes: [.v6]
)
