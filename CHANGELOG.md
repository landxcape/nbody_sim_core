## 0.1.7
- Add conditional isolate engine stubbing (`isolate_simulation_engine_stub.dart`) for Web and WebAssembly (WASM) runtime compatibility.

## 0.1.6
- Refresh README with platform compatibility matrix (Web, WASM, Desktop, Mobile).
- Update installation instructions to CLI and floating version semantics.
- Clarify automatic ABI discovery for bundled desktop Rust binaries.

## 0.1.5
- Add conditional FFI imports with web stubbing (`rust_ffi_bindings_stub.dart`), enabling full compilation and runtime compatibility on Web and WebAssembly (WASM).

## 0.1.4
- Documentation and overview refinements.

## 0.1.3
- Expanded pub.dev `topics` with `particles`.
- Added `.pubignore` to prevent bundling build and compilation caches.

## 0.1.2
- Add ABI-aware Rust native library lookup (`native/<abi>/...`) for bundled
  desktop binaries.
- Add package-root resolution via `.dart_tool/package_config.json` so bundled
  binaries inside dependency cache are discovered automatically.
- Upgrade Rust build scripts to target-specific output layout in
  `native/<abi>/`.
- Add CI workflow to build native Rust binaries for supported desktop targets.

## 0.1.1
- Improve public API documentation coverage across core models/contracts/engines.
- Refresh package metadata links for published standalone repository.

## 0.1.0
- Initial release.
- Added core models, engine interfaces/adapters, and scenario/schema helpers.
- Added embedded Rust crate and native build tooling under `rust/` and `tool/`.
