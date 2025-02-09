// swift-tools-version:5.7.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "XRPLSwift",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13),
        .tvOS(.v13),
        .watchOS(.v5)
    ],
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "XRPLSwift",
            targets: ["XRPLSwift"]
        )
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "https://github.com/GigaBitcoin/secp256k1.swift.git", .upToNextMajor(from: "0.6.0")),
        .package(url: "https://github.com/krzyzanowskim/CryptoSwift.git", from: "1.5.1"),
        .package(url: "https://github.com/attaswift/BigInt.git", from: "5.0.0"),
        .package(url: "https://github.com/Flight-School/AnyCodable.git", from: "0.4.0"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.24.0"),
        .package(url: "https://github.com/vapor/websocket-kit.git", from: "2.6.1"),
        .package(url: "https://github.com/SimplyDanny/SwiftLintPlugins", from: "<version>")
    ],
    targets: [
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "XRPLSwift",
            dependencies: [
                .product(name: "WebSocketKit", package: "websocket-kit"),
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "secp256k1", package: "secp256k1.swift"),
                "AnyCodable",
                "CryptoSwift",
                "BigInt"
            ],
            plugins: [
                .plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")
            ]
        ),
        .testTarget(
            name: "XRPLSwiftUTests",
            dependencies: ["XRPLSwift"]
        ),
        .testTarget(
            name: "XRPLSwiftITests",
            dependencies: ["XRPLSwift"]
        )
    ]
)
