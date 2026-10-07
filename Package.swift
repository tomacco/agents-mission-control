// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Helm",
    platforms: [.macOS(.v14)],
    targets: [.executableTarget(name: "Helm", path: "Sources/Helm")]
)
