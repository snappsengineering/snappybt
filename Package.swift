// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "SnappyBT",
    platforms: [
        .iOS(.v27),
        .macOS(.v27)
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
