#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CRATE_DIR="$ROOT_DIR/rust/gravity_engine"
OUTPUT_DIR="$ROOT_DIR/native"

mkdir -p "$OUTPUT_DIR"

declare -a TARGETS=()

if [[ $# -gt 0 ]]; then
  TARGETS=("$@")
else
  case "$(uname -s)" in
    Darwin*)
      TARGETS=("aarch64-apple-darwin")
      ;;
    Linux*)
      TARGETS=("x86_64-unknown-linux-gnu")
      ;;
    MINGW*|MSYS*|CYGWIN*)
      TARGETS=("x86_64-pc-windows-msvc")
      ;;
    *)
      echo "Unsupported platform for shell build script"
      exit 1
      ;;
  esac
fi

TARGET_DIR="${CARGO_TARGET_DIR:-$CRATE_DIR/target}"

lib_name_for_target() {
  local target="$1"
  case "$target" in
    *-apple-darwin|*-apple-ios)
      echo "libgravity_engine.dylib"
      ;;
    *-windows-*)
      echo "gravity_engine.dll"
      ;;
    *)
      echo "libgravity_engine.so"
      ;;
  esac
}

abi_folder_for_target() {
  local target="$1"
  case "$target" in
    aarch64-apple-darwin) echo "macos-arm64" ;;
    x86_64-apple-darwin) echo "macos-x64" ;;
    aarch64-unknown-linux-gnu) echo "linux-arm64" ;;
    x86_64-unknown-linux-gnu) echo "linux-x64" ;;
    armv7-unknown-linux-gnueabihf) echo "linux-arm" ;;
    i686-unknown-linux-gnu) echo "linux-ia32" ;;
    x86_64-pc-windows-msvc|x86_64-pc-windows-gnu) echo "windows-x64" ;;
    i686-pc-windows-msvc|i686-pc-windows-gnu) echo "windows-ia32" ;;
    aarch64-pc-windows-msvc) echo "windows-arm64" ;;
    aarch64-linux-android) echo "android-arm64" ;;
    x86_64-linux-android) echo "android-x64" ;;
    i686-linux-android) echo "android-ia32" ;;
    armv7-linux-androideabi) echo "android-arm" ;;
    aarch64-apple-ios) echo "ios-arm64" ;;
    x86_64-apple-ios) echo "ios-x64" ;;
    *) echo "" ;;
  esac
}

pushd "$CRATE_DIR" >/dev/null
for target in "${TARGETS[@]}"; do
  abi_folder="$(abi_folder_for_target "$target")"
  if [[ -z "$abi_folder" ]]; then
    echo "Unsupported target mapping: $target"
    exit 1
  fi

  lib_name="$(lib_name_for_target "$target")"
  echo "Building $target..."
  cargo build --release --lib --target "$target"

  src="$TARGET_DIR/$target/release/$lib_name"
  dest_dir="$OUTPUT_DIR/$abi_folder"
  mkdir -p "$dest_dir"
  cp "$src" "$dest_dir/$lib_name"
  echo "Copied: $dest_dir/$lib_name"
done
popd >/dev/null

echo "Rust engine build complete."
