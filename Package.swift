// swift-tools-version:5.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Interplate",
    products: [
        .library(name: "Interplate", targets: ["Interplate"])
    ],
    dependencies: [
        .package(url: "https://github.com/ilyapuchka/swift-prelude.git", .branch("master")),
    ],
    targets: [
        .target(name: "Interplate", dependencies: ["Prelude"]),
        .testTarget(name: "InterplateTests", dependencies: ["Interplate"])
    ]
)
