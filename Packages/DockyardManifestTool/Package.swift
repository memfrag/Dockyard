// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "DockyardManifestTool",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .executable(name: "dockyard-manifest-tool", targets: ["DockyardManifestTool"])
    ],
    dependencies: [
        .package(path: "../DockyardEngine"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0")
    ],
    targets: [
        .executableTarget(
            name: "DockyardManifestTool",
            dependencies: [
                "DockyardEngine",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        )
    ]
)
