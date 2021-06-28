// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "webber-tools",
    platforms: [
       .macOS(.v10_15)
    ],
    products: [
        .library(name: "WebberTools", targets: ["WebberTools"]),
    ],
    dependencies: [],
    targets: [
        .target(name: "WebberTools", dependencies: []),
        .testTarget(name: "WebberToolsTests", dependencies: ["WebberTools"]),
    ]
)
