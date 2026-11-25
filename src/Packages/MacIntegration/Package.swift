// swift-tools-version: 6.4
import PackageDescription

/// macOS integration: screen capture, input injection, accounts, displays and permissions.
let package = Package(
    name: "MacIntegration",
    platforms: [.macOS(.v15)],
    products: [.library(name: "MacIntegration", targets: ["MacIntegration"])],
    dependencies: [
        .package(path: "../RdpProtocol"),
        .package(path: "../RdpServer"),
        .package(path: "../IRdpConfiguration"),
    ],
    targets: [
        .target(
            name: "MacIntegration",
            dependencies: [
                .product(name: "RdpProtocol", package: "RdpProtocol"),
                .product(name: "RdpServer", package: "RdpServer"),
                .product(name: "IRdpConfiguration", package: "IRdpConfiguration"),
            ]
        ),
        .testTarget(name: "MacIntegrationTests", dependencies: ["MacIntegration"]),
    ],
    swiftLanguageModes: [.v6]
)
