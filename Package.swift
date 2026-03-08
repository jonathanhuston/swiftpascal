// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "SwiftPascal",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "SwiftPascal",
            dependencies: ["SwiftPascalCore"]
        ),
        .target(
            name: "SwiftPascalCore"
        ),
        .testTarget(
            name: "SwiftPascalCoreTests",
            dependencies: ["SwiftPascalCore"]
        ),
    ]
)
