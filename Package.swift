// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MiaApp",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "MiaApp",
            path: "Sources/MiaApp"
        )
    ]
)
