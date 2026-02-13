# nbody_sim_core

Engine-agnostic N-body simulation core package for Dart.

## Features
- Simulation models and contracts
- Scenario and snapshot import/export helpers
- Dart engine adapter
- Isolate and Rust FFI adapter interfaces
- Rust physics crate and native build tooling (`rust/gravity_engine`, `tool/build_rust_engine.*`)

## Usage
```dart
import 'package:nbody_sim_core/nbody_sim_core.dart';

final engine = DartSimulationEngine();
await engine.initialize(
  config: SimulationConfig.scientificDefault,
  bodies: const [],
);
```
