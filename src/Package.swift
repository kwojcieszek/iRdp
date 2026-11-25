// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "iRdp",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "iRdp", targets: ["iRdp"]),
        .executable(name: "iRdpService", targets: ["iRdpService"]),
        .library(name: "RdpProtocol", targets: ["RdpProtocol"]),
        .library(name: "RdpServer", targets: ["RdpServer"]),
        .library(name: "IRdpConfiguration", targets: ["IRdpConfiguration"]),
        .library(name: "MacIntegration", targets: ["MacIntegration"]),
        .library(name: "IRdpServiceCore", targets: ["IRdpServiceCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.65.0"),
        .package(url: "https://github.com/apple/swift-nio-ssl.git", from: "2.27.0"),
        .package(url: "https://github.com/apple/swift-certificates.git", from: "1.5.0"),
        .package(url: "https://github.com/apple/swift-crypto.git", "3.0.0"..<"5.0.0"),
        .package(url: "https://github.com/apple/swift-asn1.git", from: "1.0.0"),
    ],
    targets: [
        .target(name: "RdpProtocol"),
        .target(
            name: "RdpServer",
            dependencies: [
                "RdpProtocol",
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "NIOSSL", package: "swift-nio-ssl"),
                .product(name: "X509", package: "swift-certificates"),
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "_CryptoExtras", package: "swift-crypto"),
                .product(name: "SwiftASN1", package: "swift-asn1"),
            ]
        ),
        .target(name: "IRdpConfiguration"),
        .target(name: "MacIntegration", dependencies: ["RdpProtocol", "RdpServer", "IRdpConfiguration"]),
        .target(name: "IRdpServiceCore", dependencies: ["RdpServer", "IRdpConfiguration", "MacIntegration"]),
        .executableTarget(name: "iRdpService", dependencies: ["IRdpServiceCore"]),
        .executableTarget(name: "iRdp", dependencies: ["IRdpConfiguration", "MacIntegration"]),
        .testTarget(name: "RdpProtocolTests", dependencies: ["RdpProtocol"]),
        .testTarget(
            name: "RdpServerTests",
            dependencies: [
                "RdpServer",
                "RdpProtocol",
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "NIOSSL", package: "swift-nio-ssl"),
                .product(name: "NIOEmbedded", package: "swift-nio"),
            ]
        ),
        .testTarget(name: "IRdpConfigurationTests", dependencies: ["IRdpConfiguration"]),
        .testTarget(name: "MacIntegrationTests", dependencies: ["MacIntegration"]),
        .testTarget(name: "IRdpServiceCoreTests", dependencies: ["IRdpServiceCore"]),
    ],
    swiftLanguageModes: [.v6]
)
