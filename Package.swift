// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SnappyBT",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
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
