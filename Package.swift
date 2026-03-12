// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "NetRunner",
    platforms: [
        .macOS(.v11), .iOS(.v13), .tvOS(.v13), .watchOS(.v7)
    ],
    products: [
        .library(
            name: "NetRunner",
            targets: ["NetRunner"]),
    ],
    targets: [
        .target(
            name: "NetRunner",
            dependencies: [],
            swiftSettings: [.swiftLanguageMode(.v5)]),
        .testTarget(
            name: "NetRunnerTests",
            dependencies: ["NetRunner"],
            swiftSettings: [.swiftLanguageMode(.v5)]),
    ]
)
