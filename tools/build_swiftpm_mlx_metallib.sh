#!/bin/sh
# SwiftPM builds the pinned MLX C++ sources but does not cook its Metal resource.
# Build the JIT support kernels from that same resolved dependency checkout.
set -eu
configuration=${1:-debug}
case "$configuration" in debug|release) ;; *) printf '%s\n' 'usage: build_swiftpm_mlx_metallib.sh [debug|release]' >&2; exit 2 ;; esac
repository_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
cd "$repository_root"
mlx_source="$repository_root/.build/checkouts/mlx-swift/Source/Cmlx/mlx"
if [ ! -f "$mlx_source/CMakeLists.txt" ]; then
    printf '%s\n' 'Run swift build (or swift build --build-tests) to resolve the pinned MLX dependency first.' >&2
    exit 2
fi
binary_directory=$(swift build --configuration "$configuration" --show-bin-path)
cmake -S "$mlx_source" -B "$repository_root/.build/mlx-metallib-$configuration" \
    -DMLX_BUILD_TESTS=OFF -DMLX_BUILD_EXAMPLES=OFF -DMLX_BUILD_BENCHMARKS=OFF \
    -DMLX_BUILD_CUDA=OFF -DMLX_BUILD_GGUF=OFF -DMLX_BUILD_SAFETENSORS=OFF \
    -DMLX_METAL_JIT=ON -DMLX_METAL_PATH="$binary_directory"
cmake --build "$repository_root/.build/mlx-metallib-$configuration" \
    --target mlx-metallib --parallel "${NUMI_BUILD_JOBS:-2}"
# MLX searches beside the calling executable. XCTest has a nested executable.
for bundle in "$binary_directory"/*.xctest; do
    destination="$bundle/Contents/MacOS"
    if [ -d "$destination" ]; then
        cp "$binary_directory/mlx.metallib" "$destination/mlx.metallib.tmp-$$"
        mv "$destination/mlx.metallib.tmp-$$" "$destination/mlx.metallib"
    fi
done
shasum -a 256 "$binary_directory/mlx.metallib"
