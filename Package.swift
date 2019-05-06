// swift-tools-version:5.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Interplate",
    products: [
        .library(name: "Interplate", targets: ["Interplate"])
    ],
    dependencies: [
        .package(url: "https://github.com/ilyapuchka/common-parsers.git", .branch("master"))
    ],
    targets: [
        .target(name: "Interplate", dependencies: ["CommonParsers"]),
        .testTarget(name: "InterplateTests", dependencies: ["Interplate"])
    ]
)
