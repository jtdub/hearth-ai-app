// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LlamaCpp",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "LlamaCpp", targets: ["LlamaCpp"])
    ],
    targets: [
        .target(
            name: "CLlama",
            path: "Sources/CLlama",
            publicHeadersPath: "include",
            cSettings: [
                .define("GGML_USE_METAL"),
                .define("GGML_USE_ACCELERATE"),
                .define("ACCELERATE_NEW_LAPACK"),
            ],
            cxxSettings: [
                .define("GGML_USE_METAL"),
                .define("GGML_USE_ACCELERATE"),
            ],
            linkerSettings: [
                .linkedFramework("Metal"),
                .linkedFramework("MetalKit"),
                .linkedFramework("MetalPerformanceShaders"),
                .linkedFramework("Accelerate"),
                .linkedFramework("Foundation"),
            ]
        ),
        .target(
            name: "LlamaCpp",
            dependencies: ["CLlama"],
            path: "Sources/LlamaCpp"
        )
    ],
    cxxLanguageStandard: .cxx17
)
