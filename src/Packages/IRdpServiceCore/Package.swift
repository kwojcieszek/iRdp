// swift-tools-version: 6.4
import PackageDescription

/// Service runtime: applies settings, runs the RDP server, authenticates clients and reports status.
let package = Package(
    name: "IRdpServiceCore",
    platforms: [.macOS(.v15)],
    products: [.library(name: "IRdpServiceCore", targets: ["IRdpServiceCore"])],
    dependencies: [
        .package(path: "../RdpServer"),
        .package(path: "../IRdpConfiguration"),
        .package(path: "../MacIntegration"),
    ],
    targets: [
        .target(
            name: "IRdpServiceCore",
            dependencies: [
                .product(name: "RdpServer", package: "RdpServer"),
                .product(name: "IRdpConfiguration", package: "IRdpConfiguration"),
                .product(name: "MacIntegration", package: "MacIntegration"),
            ]
        ),
        .testTarget(name: "IRdpServiceCoreTests", dependencies: ["IRdpServiceCore"]),
    ],
    swiftLanguageModes: [.v6]
)
