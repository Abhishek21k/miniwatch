// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "miniwatch",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "MiniwatchCore"),
        .executableTarget(name: "miniwatch", dependencies: ["MiniwatchCore"]),
        .testTarget(name: "MiniwatchCoreTests", dependencies: ["MiniwatchCore"]),
    ]
)
