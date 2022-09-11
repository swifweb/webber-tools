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
    dependencies: [
		.package(url: "https://github.com/apple/swift-crypto.git", "1.0.0" ..< "3.0.0"),
	],
    targets: [
        .target(name: "WebberTools", dependencies: [
			.product(name: "Crypto", package: "swift-crypto")
		]),
        .testTarget(name: "WebberToolsTests", dependencies: ["WebberTools"]),
    ]
)
