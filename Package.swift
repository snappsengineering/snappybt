// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SnappyBT",
    platforms: [
        .iOS(.v18),
        .macOS(.v15)
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
