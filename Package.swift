// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Tranz",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "Tranz",
            path: "Sources/Tranz"
        )
    ]
)
