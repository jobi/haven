// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "NativeHA",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "NativeHACore",
            targets: ["NativeHACore"]
        ),
        .executable(
            name: "NativeHAApp",
            targets: ["NativeHAApp"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "NativeHACore",
            dependencies: [],
            path: "Sources/NativeHACore"
        ),
        .executableTarget(
            name: "NativeHAApp",
            dependencies: ["NativeHACore"],
            path: "Sources/NativeHAApp"
        ),
        .testTarget(
            name: "NativeHATests",
            dependencies: ["NativeHACore"],
            path: "Tests/NativeHATests"
        )
    ]
)
