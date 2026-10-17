// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "SnappyBT",
    platforms: [
        .iOS(.v26),
        .macOS(.v26)
    ],
    products: [
        .library(name: "SnappyBT", targets: ["SnappyBT"]),
    ],
    targets: [
        .target(
            name: "SnappyBT",
            path: "Sources/SnappyBT"
        ),
        .testTarget(
            name: "SnappyBTTests",
            dependencies: ["SnappyBT"],
            path: "Tests/SnappyBTTests"
        ),
    ]
)
