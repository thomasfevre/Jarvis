// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Jarvis",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(name: "JarvisCore", targets: ["JarvisCore"]),
        .executable(name: "jarvis", targets: ["JarvisCLI"]),
    ],
    targets: [
        .target(name: "JarvisCore"),
        .executableTarget(
            name: "JarvisCLI",
            dependencies: ["JarvisCore"]
        ),
        .testTarget(
            name: "JarvisCoreTests",
            dependencies: ["JarvisCore"]
        ),
        .testTarget(
            name: "JarvisCLITests",
            dependencies: ["JarvisCLI", "JarvisCore"]
        ),
    ]
)
