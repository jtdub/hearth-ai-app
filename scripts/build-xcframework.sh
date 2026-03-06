#!/usr/bin/env bash
#
# Builds llama.cpp as an XCFramework for iOS device + simulator.
# Output: Packages/LlamaCpp/llama.xcframework/
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LLAMA_CPP_DIR="$PROJECT_ROOT/Packages/LlamaCpp/vendored/llama.cpp"
OUTPUT_DIR="$PROJECT_ROOT/Packages/LlamaCpp"
BUILD_DIR="$PROJECT_ROOT/build-llama"

IOS_MIN_VERSION="17.0"

if [ ! -d "$LLAMA_CPP_DIR" ]; then
    echo "Error: llama.cpp not found at $LLAMA_CPP_DIR"
    echo "Run: git submodule update --init --recursive"
    exit 1
fi

echo "=== Building llama.cpp XCFramework ==="
echo "Source: $LLAMA_CPP_DIR"
echo "Output: $OUTPUT_DIR/llama.xcframework"

# Clean previous builds
rm -rf "$BUILD_DIR"
rm -rf "$OUTPUT_DIR/llama.xcframework"

COMMON_CMAKE_ARGS=(
    -DBUILD_SHARED_LIBS=OFF
    -DLLAMA_BUILD_EXAMPLES=OFF
    -DLLAMA_BUILD_TOOLS=OFF
    -DLLAMA_BUILD_TESTS=OFF
    -DLLAMA_BUILD_SERVER=OFF
    -DGGML_METAL=ON
    -DGGML_METAL_EMBED_LIBRARY=ON
    -DGGML_METAL_USE_BF16=ON
    -DGGML_BLAS_DEFAULT=ON
    -DGGML_NATIVE=OFF
    -DGGML_OPENMP=OFF
    -DCMAKE_BUILD_TYPE=Release
)

# Build for iOS device (arm64)
echo ""
echo "--- Building for iOS device (arm64) ---"
DEVICE_SDK=$(xcrun --sdk iphoneos --show-sdk-path)
cmake -B "$BUILD_DIR/ios-device" -S "$LLAMA_CPP_DIR" -G "Unix Makefiles" \
    "${COMMON_CMAKE_ARGS[@]}" \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_DEPLOYMENT_TARGET="$IOS_MIN_VERSION" \
    -DCMAKE_OSX_ARCHITECTURES="arm64" \
    -DCMAKE_OSX_SYSROOT="$DEVICE_SDK" \
    -DCMAKE_C_COMPILER="$(xcrun --sdk iphoneos --find clang)" \
    -DCMAKE_CXX_COMPILER="$(xcrun --sdk iphoneos --find clang++)"

cmake --build "$BUILD_DIR/ios-device" --config Release -j "$(sysctl -n hw.ncpu)"

# Build for iOS simulator (arm64)
echo ""
echo "--- Building for iOS simulator (arm64) ---"
SIMULATOR_SDK=$(xcrun --sdk iphonesimulator --show-sdk-path)
cmake -B "$BUILD_DIR/ios-simulator" -S "$LLAMA_CPP_DIR" -G "Unix Makefiles" \
    "${COMMON_CMAKE_ARGS[@]}" \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_DEPLOYMENT_TARGET="$IOS_MIN_VERSION" \
    -DCMAKE_OSX_ARCHITECTURES="arm64" \
    -DCMAKE_OSX_SYSROOT="$SIMULATOR_SDK" \
    -DCMAKE_C_COMPILER="$(xcrun --sdk iphonesimulator --find clang)" \
    -DCMAKE_CXX_COMPILER="$(xcrun --sdk iphonesimulator --find clang++)" \
    -DCMAKE_C_FLAGS="-target arm64-apple-ios${IOS_MIN_VERSION}-simulator" \
    -DCMAKE_CXX_FLAGS="-target arm64-apple-ios${IOS_MIN_VERSION}-simulator"

cmake --build "$BUILD_DIR/ios-simulator" --config Release -j "$(sysctl -n hw.ncpu)"

# Find and collect static libraries
echo ""
echo "--- Collecting static libraries ---"

collect_libs() {
    local build_dir=$1
    local dest_dir=$2
    mkdir -p "$dest_dir"

    find "$build_dir" -name "*.a" -not -path "*/CMakeFiles/*" | while read -r lib; do
        local name
        name=$(basename "$lib")
        echo "  Found: $name"
        cp "$lib" "$dest_dir/$name"
    done
}

collect_libs "$BUILD_DIR/ios-device" "$BUILD_DIR/libs/device"
collect_libs "$BUILD_DIR/ios-simulator" "$BUILD_DIR/libs/simulator"

# Merge all static libs into a single archive per platform
echo ""
echo "--- Merging into single static library per platform ---"

merge_libs() {
    local platform=$1
    local output="$BUILD_DIR/merged/${platform}/libllama_all.a"
    local libs=()

    mkdir -p "$BUILD_DIR/merged/${platform}"

    for f in "$BUILD_DIR/libs/${platform}"/lib*.a; do
        if [ -f "$f" ]; then
            libs+=("$f")
        fi
    done

    if [ ${#libs[@]} -eq 0 ]; then
        echo "Error: No libraries found for $platform"
        exit 1
    fi

    echo "  Merging ${#libs[@]} libraries for $platform"
    libtool -static -o "$output" "${libs[@]}"
    echo "  Created: $output ($(du -h "$output" | cut -f1))"
}

merge_libs "device"
merge_libs "simulator"

# Collect headers
echo ""
echo "--- Collecting headers ---"
HEADERS_DIR="$BUILD_DIR/headers"
mkdir -p "$HEADERS_DIR"

cp "$LLAMA_CPP_DIR/include/llama.h" "$HEADERS_DIR/"
cp "$LLAMA_CPP_DIR/ggml/include/ggml.h" "$HEADERS_DIR/"
cp "$LLAMA_CPP_DIR/ggml/include/ggml-alloc.h" "$HEADERS_DIR/"
cp "$LLAMA_CPP_DIR/ggml/include/ggml-backend.h" "$HEADERS_DIR/"
cp "$LLAMA_CPP_DIR/ggml/include/ggml-metal.h" "$HEADERS_DIR/"
cp "$LLAMA_CPP_DIR/ggml/include/ggml-cpu.h" "$HEADERS_DIR/"
cp "$LLAMA_CPP_DIR/ggml/include/ggml-opt.h" "$HEADERS_DIR/"
cp "$LLAMA_CPP_DIR/ggml/include/gguf.h" "$HEADERS_DIR/"

# Create module map for Swift interop
cat > "$HEADERS_DIR/module.modulemap" << 'MODULEMAP'
module llama {
    header "llama.h"
    header "ggml.h"
    header "ggml-alloc.h"
    header "ggml-backend.h"
    header "ggml-metal.h"
    header "ggml-cpu.h"
    header "gguf.h"
    export *
}
MODULEMAP

# Create XCFramework
echo ""
echo "--- Creating XCFramework ---"
xcodebuild -create-xcframework \
    -library "$BUILD_DIR/merged/device/libllama_all.a" \
    -headers "$HEADERS_DIR" \
    -library "$BUILD_DIR/merged/simulator/libllama_all.a" \
    -headers "$HEADERS_DIR" \
    -output "$OUTPUT_DIR/llama.xcframework"

echo ""
echo "=== XCFramework created at: $OUTPUT_DIR/llama.xcframework ==="
echo "Size: $(du -sh "$OUTPUT_DIR/llama.xcframework" | cut -f1)"

# Clean up build directory
rm -rf "$BUILD_DIR"

echo ""
echo "Done! You can now build the Xcode project."
