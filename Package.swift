// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NetPulse",
    platforms: [.macOS(.v12)],
    products: [
        .executable(name: "NetPulse", targets: ["NetPulse"])
    ],
    targets: [
        .executableTarget(
            name: "NetPulse",
            path: "Sources/NetPulse"
        )
    ]
)
