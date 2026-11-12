// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Hollow",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(name: "Hollow"),
        .testTarget(name: "HollowTests", dependencies: ["Hollow"]),

        // Hollow's own Google Drive client, for the FSKit version (no rclone).
        .target(name: "HollowDrive"),
        .testTarget(name: "HollowDriveTests", dependencies: ["HollowDrive"]),
        // Live check against a real Drive: swift run hollow-drive-check <client.json>
        .executableTarget(name: "hollow-drive-check", dependencies: ["HollowDrive"]),
    ]
)
