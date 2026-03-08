// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LlamaCpp",
    platforms: [.iOS(.v17), .macOS(.v14), .visionOS(.v1)],
    products: [
        .library(name: "LlamaCpp", targets: ["LlamaCpp"])
    ],
    targets: [
        .binaryTarget(
            name: "llama",
            path: "llama.xcframework"
        ),
        .target(
            name: "LlamaCpp",
            dependencies: ["llama"],
            path: "Sources/LlamaCpp",
            linkerSettings: [
                .linkedLibrary("c++"),
                .linkedFramework("Metal"),
                .linkedFramework("MetalKit"),
                .linkedFramework("MetalPerformanceShaders"),
                .linkedFramework("Accelerate"),
                .linkedFramework("Foundation"),
            ]
        )
    ]
)
