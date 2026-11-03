// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "CloudflareTunnel",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "CloudflareTunnel", path: "Sources/CloudflareTunnel")
    ]
)
