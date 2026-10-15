// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "AgentsMissionControl",
    platforms: [.macOS("26.0")],
    targets: [.executableTarget(name: "AgentsMissionControl", path: "Sources/AgentsMissionControl")]
)
