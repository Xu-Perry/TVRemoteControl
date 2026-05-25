// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "TVRemoteModules",
    platforms: [
        .iOS(.v18),
        .macOS(.v12)
    ],
    products: [
        .library(name: "TVRemoteCore", targets: ["TVRemoteCore"]),
        .library(name: "TVRemoteNetworking", targets: ["TVRemoteNetworking"])
    ],
    targets: [
        .target(name: "TVRemoteCore"),
        .target(
            name: "TVRemoteNetworking",
            dependencies: ["TVRemoteCore"]
        ),
        .testTarget(
            name: "TVRemoteCoreTests",
            dependencies: ["TVRemoteCore"]
        ),
        .testTarget(
            name: "TVRemoteNetworkingTests",
            dependencies: ["TVRemoteNetworking"]
        )
    ]
)
