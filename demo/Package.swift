// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OddSocketsDemo",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        // Use the SDK from the parent directory (clone-and-run).
        .package(path: "..")
    ],
    targets: [
        .executableTarget(
            name: "OddSocketsDemo",
            dependencies: [
                .product(name: "OddSockets", package: "oddsockets-swift-sdk")
            ],
            path: "Sources/OddSocketsDemo"
        )
    ]
)
