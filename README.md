# nbody_sim_core

Engine-agnostic N-body simulation core package for Dart.

`nbody_sim_core` provides:
1. Physics domain models and contracts.
2. Multiple engine backends (`Dart`, `Isolate`, `Rust FFI`).
3. Scenario and snapshot serialization utilities.
4. Schema migration and validation helpers.
5. Embedded Rust crate + native build scripts.

## Install

```yaml
dependencies:
  nbody_sim_core: ^0.1.0
```

## Public API

```dart
import 'package:nbody_sim_core/nbody_sim_core.dart';
```

Barrel exports:
1. `models.dart`: configs, vectors, bodies, state, telemetry, edit contracts.
2. `engine.dart`: `SimulationEngine` + concrete backends.
3. `scenario.dart`: schema validator + migrator APIs.

## Core Concepts

1. `SimulationConfig`
   - Integrator: `semiImplicitEuler`, `velocityVerlet`, `rk4`
   - Collision: `elastic`, `inelasticMerge`, `ignore`
   - dt policy: `fixed`, `adaptive`
   - Solver: `pairwise`, `barnesHut`, `auto`
2. `SimulationBody`
   - Required: `id`, `mass`, `radius`, `position`, `velocity`, `colorValue`
3. `SimulationEngine` contract
   - `initialize`, `setConfig`, `applyEdit`, `step`
   - `loadScenario`, `saveScenario`
   - `snapshot`, `restoreSnapshot`
   - `getState`, `dispose`

## Quick Start (Pure Dart backend)

```dart
import 'package:nbody_sim_core/nbody_sim_core.dart';

Future<void> main() async {
  final engine = DartSimulationEngine();

  await engine.initialize(
    config: SimulationConfig.scientificDefault,
    bodies: const [
      SimulationBody(
        id: 'sun',
        mass: 1000,
        radius: 2.0,
        position: Vec2.zero,
        velocity: Vec2.zero,
        colorValue: 0xFFFFD54F,
      ),
      SimulationBody(
        id: 'planet',
        mass: 1,
        radius: 0.5,
        position: Vec2(12, 0),
        velocity: Vec2(0, 9.2),
        colorValue: 0xFF64B5F6,
      ),
    ],
  );

  final summary = await engine.step(240);
  final state = engine.getState();

  print('tick=${state.tick}, simTime=${state.simTime}, mode=${summary.lastSolverMode}');
  await engine.dispose();
}
```

## Backend Options

Use whichever backend fits your runtime and performance goals.

1. `DartSimulationEngine`
   - Easiest setup.
   - No native prerequisites.
2. `IsolateSimulationEngine`
   - Runs simulation off the UI/main isolate.
   - Backend selection: `EngineBackend.auto`, `EngineBackend.rust`, `EngineBackend.dart`.
3. `RustFfiSimulationEngine`
   - Direct native Rust backend.
   - Highest performance path when native library is present.

Example:

```dart
import 'package:nbody_sim_core/engine.dart';
import 'package:nbody_sim_core/models.dart';

final engine = IsolateSimulationEngine(
  backend: EngineBackend.auto,
  // Optional:
  // rustLibraryPath: '/absolute/path/to/libgravity_engine.dylib',
);
```

Direct Rust backend:

```dart
import 'package:nbody_sim_core/engine.dart';

final engine = RustFfiSimulationEngine(
  // Optional if GRAVITY_ENGINE_LIB is set or library is in ./native:
  libraryPath: '/absolute/path/to/libgravity_engine.dylib',
);
```

## Rust Native Build

The package includes:
1. Rust crate: `rust/gravity_engine`
2. Build scripts:
   - `tool/build_rust_engine.sh`
   - `tool/build_rust_engine.ps1`

From package root:

```bash
# Run Rust tests
cargo test --manifest-path rust/gravity_engine/Cargo.toml

# Build native library and copy to ./native
./tool/build_rust_engine.sh
```

On Windows PowerShell:

```powershell
.\tool\build_rust_engine.ps1
```

Generated library names:
1. macOS: `libgravity_engine.dylib`
2. Linux: `libgravity_engine.so`
3. Windows: `gravity_engine.dll`

## Rust Library Discovery

When using Rust backends, `RustFfiBindings` resolves the native library in this order:
1. Explicit `libraryPath` passed into engine/bindings.
2. `GRAVITY_ENGINE_LIB` environment variable.
3. `./native/<platform-library-name>`
4. `./rust/gravity_engine/target/release/<platform-library-name>`
5. Dynamic loader default lookup by filename.

## Runtime Edits (Create/Update/Delete Bodies)

```dart
import 'package:nbody_sim_core/models.dart';

await engine.applyEdit(
  const BodyCreate(
    SimulationBody(
      id: 'probe',
      mass: 0.1,
      radius: 0.1,
      position: Vec2(0, 20),
      velocity: Vec2(6, 0),
      colorValue: 0xFFFFFFFF,
    ),
  ),
);

await engine.applyEdit(
  const BodyUpdate(
    id: 'probe',
    velocity: Vec2(6.5, 0.2),
    label: 'Science Probe',
    kind: 'probe',
  ),
);

await engine.applyEdit(const BodyDelete('probe'));
```

## Scenario and Snapshot APIs

```dart
import 'package:nbody_sim_core/models.dart';

// Save current state as scenario
final scenario = await engine.saveScenario();

// Restore scenario
await engine.loadScenario(scenario);

// Point-in-time snapshot
final snap = await engine.snapshot();
await engine.restoreSnapshot(snap);
```

JSON import/export:

```dart
import 'dart:convert';
import 'package:nbody_sim_core/models.dart';

// Export scenario JSON string
final scenario = await engine.saveScenario();
final scenarioJsonString = jsonEncode(scenario.toJson());

// Import scenario JSON string
final parsedScenarioMap = jsonDecode(scenarioJsonString) as Map<String, dynamic>;
final importedScenario = ScenarioModel.fromJson(parsedScenarioMap);
await engine.loadScenario(importedScenario);

// Export snapshot JSON string
final snapshot = await engine.snapshot();
final snapshotJsonString = jsonEncode(snapshot.toJson());

// Import snapshot JSON string
final parsedSnapshotMap = jsonDecode(snapshotJsonString) as Map<String, dynamic>;
final importedSnapshot = SnapshotModel.fromJson(parsedSnapshotMap);
await engine.restoreSnapshot(importedSnapshot);
```

## Schema Migration + Validation

```dart
import 'package:nbody_sim_core/scenario.dart';

final migrated = ScenarioSchemaMigrator.migrateToLatest(rawJson);
final issues = ScenarioSchemaValidator.validateScenarioJson(migrated);

if (issues.isNotEmpty) {
  for (final issue in issues) {
    print(issue); // "<path>: <message>"
  }
}
```

## Deterministic vs Adaptive Notes

1. Deterministic mode is designed for replayable runs.
2. `SimulationConfig.validate()` rejects `deterministic == true` with `DtPolicy.adaptive`.
3. For exact replay workflows, keep:
   - `deterministic: true`
   - `dtPolicy: DtPolicy.fixed`

## Minimal Lifecycle Pattern

```dart
final engine = IsolateSimulationEngine();
await engine.initialize(config: SimulationConfig.scientificDefault, bodies: initialBodies);
await engine.step(1);
final state = engine.getState();
await engine.dispose();
```

## Troubleshooting

1. Error: unable to open gravity engine dynamic library
   - Build native library with `./tool/build_rust_engine.sh`.
   - Set `GRAVITY_ENGINE_LIB` to an absolute library path.
   - Or pass `rustLibraryPath` explicitly.
2. `StateError: Rust engine has not been initialized`
   - Call `initialize()` before `step`, `setConfig`, `applyEdit`, etc.
3. Schema validation failures
   - Run migrator first: `ScenarioSchemaMigrator.migrateToLatest(...)`.
   - Re-run validator and inspect issue paths/messages.

## License

MIT (see `LICENSE`).
