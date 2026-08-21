// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "notchFX",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "notchFXApp",
            path: "notchFX"
        ),
        .testTarget(
            name: "notchFXTests",
            dependencies: ["notchFXApp"],
            path: "notchFXTests"
        )
    ]
)
