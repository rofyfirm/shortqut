// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Shortqut",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Shortqut",
            path: "Sources/Shortqut"
        )
    ]
)
