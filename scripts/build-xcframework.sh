#!/usr/bin/env bash
#
# Builds llama.cpp as an XCFramework for iOS, macOS, and optionally visionOS.
# Output: Packages/LlamaCpp/llama.xcframework/
#
# Usage:
#   bash scripts/build-xcframework.sh                  # Build for all available SDKs
#   bash scripts/build-xcframework.sh --platforms ios   # Build for iOS only
#   bash scripts/build-xcframework.sh --platforms ios,macos
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LLAMA_CPP_DIR="$PROJECT_ROOT/Packages/LlamaCpp/vendored/llama.cpp"
OUTPUT_DIR="$PROJECT_ROOT/Packages/LlamaCpp"
BUILD_DIR="$PROJECT_ROOT/build-llama"

IOS_MIN_VERSION="17.0"
MACOS_MIN_VERSION="14.0"
VISIONOS_MIN_VERSION="1.0"

# Parse --platforms argument
REQUESTED_PLATFORMS=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --platforms)
            REQUESTED_PLATFORMS="$2"
            shift 2
            ;;
        *)
            echo "Unknown argument: $1"
            exit 1
            ;;
    esac
done

# Detect available SDKs
has_sdk() {
    xcrun --sdk "$1" --show-sdk-path &>/dev/null
}

BUILD_IOS=false
BUILD_MACOS=false
BUILD_VISIONOS=false

if [ -n "$REQUESTED_PLATFORMS" ]; then
    IFS=',' read -ra PLATFORMS <<< "$REQUESTED_PLATFORMS"
    for platform in "${PLATFORMS[@]}"; do
        case "$platform" in
            ios) BUILD_IOS=true ;;
            macos) BUILD_MACOS=true ;;
            visionos) BUILD_VISIONOS=true ;;
            all) BUILD_IOS=true; BUILD_MACOS=true; BUILD_VISIONOS=true ;;
            *) echo "Unknown platform: $platform"; exit 1 ;;
        esac
    done
else
    # Auto-detect available SDKs
    if has_sdk iphoneos; then BUILD_IOS=true; fi
    if has_sdk macosx; then BUILD_MACOS=true; fi
    if has_sdk xros; then BUILD_VISIONOS=true; fi
fi

if [ ! -d "$LLAMA_CPP_DIR" ]; then
    echo "Error: llama.cpp not found at $LLAMA_CPP_DIR"
    echo "Run: git submodule update --init --recursive"
    exit 1
fi

echo "=== Building llama.cpp XCFramework ==="
echo "Source: $LLAMA_CPP_DIR"
echo "Output: $OUTPUT_DIR/llama.xcframework"
echo "Platforms: iOS=$BUILD_IOS macOS=$BUILD_MACOS visionOS=$BUILD_VISIONOS"

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

NUM_CPUS="$(sysctl -n hw.ncpu)"

# --- iOS ---
if [ "$BUILD_IOS" = true ]; then
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
    cmake --build "$BUILD_DIR/ios-device" --config Release -j "$NUM_CPUS"

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
    cmake --build "$BUILD_DIR/ios-simulator" --config Release -j "$NUM_CPUS"
fi

# --- macOS ---
if [ "$BUILD_MACOS" = true ]; then
    echo ""
    echo "--- Building for macOS (arm64) ---"
    MACOS_SDK=$(xcrun --sdk macosx --show-sdk-path)
    cmake -B "$BUILD_DIR/macos-arm64" -S "$LLAMA_CPP_DIR" -G "Unix Makefiles" \
        "${COMMON_CMAKE_ARGS[@]}" \
        -DCMAKE_SYSTEM_NAME=Darwin \
        -DCMAKE_OSX_DEPLOYMENT_TARGET="$MACOS_MIN_VERSION" \
        -DCMAKE_OSX_ARCHITECTURES="arm64" \
        -DCMAKE_OSX_SYSROOT="$MACOS_SDK" \
        -DCMAKE_C_COMPILER="$(xcrun --sdk macosx --find clang)" \
        -DCMAKE_CXX_COMPILER="$(xcrun --sdk macosx --find clang++)"
    cmake --build "$BUILD_DIR/macos-arm64" --config Release -j "$NUM_CPUS"

    echo ""
    echo "--- Building for macOS (x86_64) ---"
    cmake -B "$BUILD_DIR/macos-x86_64" -S "$LLAMA_CPP_DIR" -G "Unix Makefiles" \
        "${COMMON_CMAKE_ARGS[@]}" \
        -DGGML_METAL=OFF \
        -DGGML_METAL_EMBED_LIBRARY=OFF \
        -DCMAKE_SYSTEM_NAME=Darwin \
        -DCMAKE_OSX_DEPLOYMENT_TARGET="$MACOS_MIN_VERSION" \
        -DCMAKE_OSX_ARCHITECTURES="x86_64" \
        -DCMAKE_OSX_SYSROOT="$MACOS_SDK" \
        -DCMAKE_C_COMPILER="$(xcrun --sdk macosx --find clang)" \
        -DCMAKE_CXX_COMPILER="$(xcrun --sdk macosx --find clang++)"
    cmake --build "$BUILD_DIR/macos-x86_64" --config Release -j "$NUM_CPUS"
fi

# --- visionOS ---
if [ "$BUILD_VISIONOS" = true ]; then
    if has_sdk xros; then
        echo ""
        echo "--- Building for visionOS device (arm64) ---"
        VISIONOS_SDK=$(xcrun --sdk xros --show-sdk-path)
        cmake -B "$BUILD_DIR/visionos-device" -S "$LLAMA_CPP_DIR" -G "Unix Makefiles" \
            "${COMMON_CMAKE_ARGS[@]}" \
            -DCMAKE_SYSTEM_NAME=visionOS \
            -DCMAKE_OSX_DEPLOYMENT_TARGET="$VISIONOS_MIN_VERSION" \
            -DCMAKE_OSX_ARCHITECTURES="arm64" \
            -DCMAKE_OSX_SYSROOT="$VISIONOS_SDK" \
            -DCMAKE_C_COMPILER="$(xcrun --sdk xros --find clang)" \
            -DCMAKE_CXX_COMPILER="$(xcrun --sdk xros --find clang++)"
        cmake --build "$BUILD_DIR/visionos-device" --config Release -j "$NUM_CPUS"

        echo ""
        echo "--- Building for visionOS simulator (arm64) ---"
        VISIONOS_SIM_SDK=$(xcrun --sdk xrsimulator --show-sdk-path)
        cmake -B "$BUILD_DIR/visionos-simulator" -S "$LLAMA_CPP_DIR" -G "Unix Makefiles" \
            "${COMMON_CMAKE_ARGS[@]}" \
            -DCMAKE_SYSTEM_NAME=visionOS \
            -DCMAKE_OSX_DEPLOYMENT_TARGET="$VISIONOS_MIN_VERSION" \
            -DCMAKE_OSX_ARCHITECTURES="arm64" \
            -DCMAKE_OSX_SYSROOT="$VISIONOS_SIM_SDK" \
            -DCMAKE_C_COMPILER="$(xcrun --sdk xrsimulator --find clang)" \
            -DCMAKE_CXX_COMPILER="$(xcrun --sdk xrsimulator --find clang++)" \
            -DCMAKE_C_FLAGS="-target arm64-apple-xros${VISIONOS_MIN_VERSION}-simulator" \
            -DCMAKE_CXX_FLAGS="-target arm64-apple-xros${VISIONOS_MIN_VERSION}-simulator"
        cmake --build "$BUILD_DIR/visionos-simulator" --config Release -j "$NUM_CPUS"
    else
        echo "Warning: visionOS SDK not found, skipping visionOS build"
        BUILD_VISIONOS=false
    fi
fi

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

if [ "$BUILD_IOS" = true ]; then
    collect_libs "$BUILD_DIR/ios-device" "$BUILD_DIR/libs/ios-device"
    collect_libs "$BUILD_DIR/ios-simulator" "$BUILD_DIR/libs/ios-simulator"
fi
if [ "$BUILD_MACOS" = true ]; then
    collect_libs "$BUILD_DIR/macos-arm64" "$BUILD_DIR/libs/macos-arm64"
    collect_libs "$BUILD_DIR/macos-x86_64" "$BUILD_DIR/libs/macos-x86_64"
fi
if [ "$BUILD_VISIONOS" = true ]; then
    collect_libs "$BUILD_DIR/visionos-device" "$BUILD_DIR/libs/visionos-device"
    collect_libs "$BUILD_DIR/visionos-simulator" "$BUILD_DIR/libs/visionos-simulator"
fi

# Merge all static libs into a single archive per platform slice
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

if [ "$BUILD_IOS" = true ]; then
    merge_libs "ios-device"
    merge_libs "ios-simulator"
fi
if [ "$BUILD_MACOS" = true ]; then
    merge_libs "macos-arm64"
    merge_libs "macos-x86_64"

    # Create universal macOS binary with lipo
    echo "  Creating universal macOS binary (arm64 + x86_64)"
    mkdir -p "$BUILD_DIR/merged/macos-universal"
    lipo -create \
        "$BUILD_DIR/merged/macos-arm64/libllama_all.a" \
        "$BUILD_DIR/merged/macos-x86_64/libllama_all.a" \
        -output "$BUILD_DIR/merged/macos-universal/libllama_all.a"
    echo "  Created: $BUILD_DIR/merged/macos-universal/libllama_all.a ($(du -h "$BUILD_DIR/merged/macos-universal/libllama_all.a" | cut -f1))"
fi
if [ "$BUILD_VISIONOS" = true ]; then
    merge_libs "visionos-device"
    merge_libs "visionos-simulator"
fi

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

XCFRAMEWORK_ARGS=()
if [ "$BUILD_IOS" = true ]; then
    XCFRAMEWORK_ARGS+=(
        -library "$BUILD_DIR/merged/ios-device/libllama_all.a"
        -headers "$HEADERS_DIR"
        -library "$BUILD_DIR/merged/ios-simulator/libllama_all.a"
        -headers "$HEADERS_DIR"
    )
fi
if [ "$BUILD_MACOS" = true ]; then
    XCFRAMEWORK_ARGS+=(
        -library "$BUILD_DIR/merged/macos-universal/libllama_all.a"
        -headers "$HEADERS_DIR"
    )
fi
if [ "$BUILD_VISIONOS" = true ]; then
    XCFRAMEWORK_ARGS+=(
        -library "$BUILD_DIR/merged/visionos-device/libllama_all.a"
        -headers "$HEADERS_DIR"
        -library "$BUILD_DIR/merged/visionos-simulator/libllama_all.a"
        -headers "$HEADERS_DIR"
    )
fi

if [ ${#XCFRAMEWORK_ARGS[@]} -eq 0 ]; then
    echo "Error: No platforms were built"
    exit 1
fi

xcodebuild -create-xcframework \
    "${XCFRAMEWORK_ARGS[@]}" \
    -output "$OUTPUT_DIR/llama.xcframework"

echo ""
echo "=== XCFramework created at: $OUTPUT_DIR/llama.xcframework ==="
echo "Size: $(du -sh "$OUTPUT_DIR/llama.xcframework" | cut -f1)"

# Clean up build directory
rm -rf "$BUILD_DIR"

echo ""
echo "Done! You can now build the Xcode project."
