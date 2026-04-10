// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "apple-bridge",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "AppleBridgeLib",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("EventKit"),
            ]
        ),
        .executableTarget(
            name: "apple-bridge",
            dependencies: ["AppleBridgeLib"]
        ),
        .testTarget(
            name: "AppleBridgeTests",
            dependencies: ["AppleBridgeLib"]
        ),
    ]
)
