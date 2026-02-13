# Native Binary Layout

`nbody_sim_core` looks for Rust FFI libraries in ABI-scoped folders:

1. `native/macos-arm64/libgravity_engine.dylib`
2. `native/macos-x64/libgravity_engine.dylib`
3. `native/linux-x64/libgravity_engine.so`
4. `native/windows-x64/gravity_engine.dll`

Build/update binaries with:

```bash
./tool/build_rust_engine.sh <rust-target> [<rust-target>...]
```

Example:

```bash
./tool/build_rust_engine.sh aarch64-apple-darwin x86_64-apple-darwin
```

