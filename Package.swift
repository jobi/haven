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
            path: "Sources/NativeHACore",
            resources: [
                .process("Resources")
            ]
        ),
        .executableTarget(
            name: "NativeHAApp",
            dependencies: ["NativeHACore"],
            path: "Sources/NativeHAApp",
            exclude: ["Info.plist", "PrivacyInfo.xcprivacy"],
            resources: [
                .process("Assets.xcassets")
            ]
        ),
        .testTarget(
            name: "NativeHATests",
            dependencies: ["NativeHACore"],
            path: "Tests/NativeHATests"
        )
    ]
)
