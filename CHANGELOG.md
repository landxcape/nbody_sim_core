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
