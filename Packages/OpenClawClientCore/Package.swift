// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "OpenClawClientCore",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
    ],
    products: [
        .library(name: "OpenClawClientCore", targets: ["OpenClawClientCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/yunfei07/openclaw-ios-sdk.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "OpenClawClientCore",
            dependencies: [
                .product(name: "OpenClawSDK", package: "openclaw-ios-sdk"),
                .product(name: "OpenClawProtocol", package: "openclaw-ios-sdk"),
            ],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
            ]
        ),
        .testTarget(
            name: "OpenClawClientCoreTests",
            dependencies: ["OpenClawClientCore"],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
                .enableExperimentalFeature("SwiftTesting"),
            ]
        ),
    ]
)
