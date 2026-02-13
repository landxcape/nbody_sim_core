#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CRATE_DIR="$ROOT_DIR/rust/gravity_engine"
OUTPUT_DIR="$ROOT_DIR/native"

mkdir -p "$OUTPUT_DIR"

pushd "$CRATE_DIR" >/dev/null
cargo build --release --lib

case "$(uname -s)" in
  Darwin*)
    LIB_NAME="libgravity_engine.dylib"
    ;;
  Linux*)
    LIB_NAME="libgravity_engine.so"
    ;;
  MINGW*|MSYS*|CYGWIN*)
    LIB_NAME="gravity_engine.dll"
    ;;
  *)
    echo "Unsupported platform for shell build script"
    exit 1
    ;;
esac

TARGET_DIR="${CARGO_TARGET_DIR:-$CRATE_DIR/target}"
cp "$TARGET_DIR/release/$LIB_NAME" "$OUTPUT_DIR/$LIB_NAME"
popd >/dev/null

echo "Built and copied: $OUTPUT_DIR/$LIB_NAME"
