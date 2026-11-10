// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Hollow",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(name: "Hollow"),
        .testTarget(name: "HollowTests", dependencies: ["Hollow"]),
    ]
)
