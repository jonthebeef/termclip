// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ClipFix",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "clipfix",
            path: "Sources/ClipFix"
        ),
        .testTarget(
            name: "ClipFixTests",
            dependencies: ["clipfix"],
            path: "Tests/ClipFixTests"
        ),
    ]
)
