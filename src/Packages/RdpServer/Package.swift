// swift-tools-version: 6.4
import PackageDescription

/// RDP server: SwiftNIO TLS listener, connection state machine, screen update encoder.
let package = Package(
    name: "RdpServer",
    platforms: [.macOS(.v15)],
    products: [.library(name: "RdpServer", targets: ["RdpServer"])],
    dependencies: [
        .package(path: "../RdpProtocol"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.65.0"),
        .package(url: "https://github.com/apple/swift-nio-ssl.git", from: "2.27.0"),
        .package(url: "https://github.com/apple/swift-certificates.git", from: "1.5.0"),
        .package(url: "https://github.com/apple/swift-crypto.git", "3.0.0"..<"5.0.0"),
        .package(url: "https://github.com/apple/swift-asn1.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "RdpServer",
            dependencies: [
                .product(name: "RdpProtocol", package: "RdpProtocol"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "NIOSSL", package: "swift-nio-ssl"),
                .product(name: "X509", package: "swift-certificates"),
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "_CryptoExtras", package: "swift-crypto"),
                .product(name: "SwiftASN1", package: "swift-asn1"),
            ],
            // Encoding runs per pixel; keep it optimized even in Debug builds (e.g. when running from Xcode).
            swiftSettings: [.unsafeFlags(["-O"], .when(configuration: .debug))]
        ),
        .testTarget(
            name: "RdpServerTests",
            dependencies: [
                "RdpServer",
                .product(name: "RdpProtocol", package: "RdpProtocol"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "NIOSSL", package: "swift-nio-ssl"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
