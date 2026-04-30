// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SonyRemoteModules",
    platforms: [
        .iOS(.v18),
        .macOS(.v12)
    ],
    products: [
        .library(name: "SonyRemoteCore", targets: ["SonyRemoteCore"]),
        .library(name: "SonyRemoteNetworking", targets: ["SonyRemoteNetworking"])
    ],
    targets: [
        .target(name: "SonyRemoteCore"),
        .target(
            name: "SonyRemoteNetworking",
            dependencies: ["SonyRemoteCore"]
        ),
        .testTarget(
            name: "SonyRemoteCoreTests",
            dependencies: ["SonyRemoteCore"]
        ),
        .testTarget(
            name: "SonyRemoteNetworkingTests",
            dependencies: ["SonyRemoteNetworking"]
        )
    ]
)
