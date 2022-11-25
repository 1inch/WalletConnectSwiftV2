// swift-tools-version:5.5

import PackageDescription

let package = Package(
    name: "WalletConnect",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
        .tvOS(.v13)
    ],
    products: [
        .library(
            name: "WalletConnect",
            targets: ["WalletConnectSign"]),
        .library(
            name: "WalletConnectChat",
            targets: ["WalletConnectChat"]),
        .library(
            name: "WalletConnectAuth",
            targets: ["Auth"]),
        .library(
            name: "WalletConnectPairing",
            targets: ["WalletConnectPairing"]),
        .library(
            name: "WalletConnectPush",
            targets: ["WalletConnectPush"]),
        .library(
            name: "WalletConnectRouter",
            targets: ["WalletConnectRouter"]),
        .library(
            name: "WalletConnectNetworking",
            targets: ["WalletConnectNetworking"])
    ],
    dependencies: [
        .package(url: "https://github.com/gnosis/Web3.swift", revision: "420ce9f98b5ae2ccd9117515dda40819f5317036")
    ],
    targets: [
        .target(
            name: "WalletConnectSign",
            dependencies: ["WalletConnectPairing"],
            path: "Sources/WalletConnectSign"),
        .target(
            name: "WalletConnectChat",
            dependencies: ["WalletConnectNetworking"],
            path: "Sources/Chat"),
        .target(
            name: "Auth",
            dependencies: ["WalletConnectPairing", .product(name: "Web3", package: "Web3.swift")],
            path: "Sources/Auth"),
        .target(
            name: "WalletConnectPush",
            dependencies: ["WalletConnectPairing"],
            path: "Sources/WalletConnectPush"),
        .target(
            name: "WalletConnectRelay",
            dependencies: ["WalletConnectKMS"],
            path: "Sources/WalletConnectRelay",
            resources: [.copy("PackageConfig.json")]),
        .target(
            name: "WalletConnectKMS",
            dependencies: ["WalletConnectUtils"],
            path: "Sources/WalletConnectKMS"),
        .target(
            name: "WalletConnectPairing",
            dependencies: ["WalletConnectNetworking"]),
        .target(
            name: "WalletConnectUtils",
            dependencies: ["JSONRPC"]),
        .target(
            name: "JSONRPC",
            dependencies: ["Commons"]),
        .target(
            name: "Commons",
            dependencies: []),
        .target(
            name: "WalletConnectNetworking",
            dependencies: ["WalletConnectRelay"]),
        .target(
            name: "WalletConnectRouter",
            dependencies: []),
        .testTarget(
            name: "WalletConnectSignTests",
            dependencies: ["WalletConnectSign", "TestingUtils"]),
        .testTarget(
            name: "WalletConnectPairingTests",
            dependencies: ["WalletConnectPairing", "TestingUtils"]),
        .testTarget(
            name: "ChatTests",
            dependencies: ["WalletConnectChat", "WalletConnectUtils", "TestingUtils"]),
        .testTarget(
            name: "AuthTests",
            dependencies: ["Auth", "WalletConnectUtils", "TestingUtils"]),
        .testTarget(
            name: "RelayerTests",
            dependencies: ["WalletConnectRelay", "WalletConnectUtils", "TestingUtils"]),
        .testTarget(
            name: "WalletConnectKMSTests",
            dependencies: ["WalletConnectKMS", "WalletConnectUtils", "TestingUtils"]),
        .target(
            name: "TestingUtils",
            dependencies: ["WalletConnectPairing"],
            path: "Tests/TestingUtils"),
        .testTarget(
            name: "WalletConnectUtilsTests",
            dependencies: ["WalletConnectUtils", "TestingUtils"]),
        .testTarget(
            name: "JSONRPCTests",
            dependencies: ["JSONRPC", "TestingUtils"]),
        .testTarget(
            name: "CommonsTests",
            dependencies: ["Commons", "TestingUtils"])
    ],
    swiftLanguageVersions: [.v5]
)
