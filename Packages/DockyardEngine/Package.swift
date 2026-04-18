// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "DockyardEngine",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .library(name: "DockyardEngine", targets: ["DockyardEngine"])
    ],
    targets: [
        .target(name: "DockyardEngine", dependencies: []),
        .testTarget(name: "DockyardEngineTests", dependencies: ["DockyardEngine"])
    ]
)
