// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Termclip",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "termclip",
            path: "Sources/Termclip"
        ),
        .testTarget(
            name: "TermclipTests",
            dependencies: ["termclip"],
            path: "Tests/TermclipTests"
        ),
    ]
)
