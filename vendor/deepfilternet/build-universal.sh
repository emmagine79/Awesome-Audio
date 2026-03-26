#!/bin/bash
# Build DeepFilterNet as a universal static library for macOS (arm64 + x86_64)
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DFNET_DIR="$SCRIPT_DIR/DeepFilterNet/libDF"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
OUT_DIR="$SCRIPT_DIR"

source "$HOME/.cargo/env" 2>/dev/null || true

echo "Building DeepFilterNet for aarch64-apple-darwin..."
cd "$DFNET_DIR"
cargo build --release --features capi --target aarch64-apple-darwin

echo "Building DeepFilterNet for x86_64-apple-darwin..."
cargo build --release --features capi --target x86_64-apple-darwin

echo "Creating universal binary..."
lipo -create \
    "$SCRIPT_DIR/DeepFilterNet/target/aarch64-apple-darwin/release/libdf.a" \
    "$SCRIPT_DIR/DeepFilterNet/target/x86_64-apple-darwin/release/libdf.a" \
    -output "$OUT_DIR/libdeepfilter.a"

echo "Generating C header..."
cbindgen --config "$SCRIPT_DIR/DeepFilterNet/cbindgen.toml" \
    --crate df \
    --output "$PROJECT_DIR/AwesomeAudio/Bridge/deep_filter.h" \
    "$DFNET_DIR" 2>/dev/null || echo "Warning: cbindgen had issues (header may still be valid)"

echo ""
echo "Done!"
echo "  Static lib: $OUT_DIR/libdeepfilter.a"
echo "  Header:     $PROJECT_DIR/AwesomeAudio/Bridge/deep_filter.h"
echo "  Model:      $PROJECT_DIR/AwesomeAudio/Resources/DeepFilterNet3_onnx.tar.gz"
file "$OUT_DIR/libdeepfilter.a"
