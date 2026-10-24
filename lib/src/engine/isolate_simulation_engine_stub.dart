import '../model/engine_contract.dart';
import '../model/simulation_body.dart';
import '../model/simulation_config.dart';
import '../model/simulation_state.dart';
import 'simulation_engine.dart';

enum EngineBackend { auto, rust, dart }

/// Fallback stub for [IsolateSimulationEngine] on platforms without `dart:isolate` (e.g. Web).
class IsolateSimulationEngine implements SimulationEngine {
  IsolateSimulationEngine({
    this.backend = EngineBackend.auto,
    this.rustLibraryPath,
  });

  final EngineBackend backend;
  final String? rustLibraryPath;

  @override
  Future<void> initialize({
    required SimulationConfig config,
    required List<SimulationBody> bodies,
  }) {
    throw UnsupportedError(
      'IsolateSimulationEngine is not supported on web runtimes. '
      'Use DartSimulationEngine instead.',
    );
  }

  @override
  Future<void> setConfig(SimulationConfig config) {
    throw UnsupportedError(
      'IsolateSimulationEngine is not supported on web runtimes. '
      'Use DartSimulationEngine instead.',
    );
  }

  @override
  Future<void> applyEdit(BodyEdit edit) {
    throw UnsupportedError(
      'IsolateSimulationEngine is not supported on web runtimes. '
      'Use DartSimulationEngine instead.',
    );
  }

  @override
  Future<StepSummary> step(int ticks) {
    throw UnsupportedError(
      'IsolateSimulationEngine is not supported on web runtimes. '
      'Use DartSimulationEngine instead.',
    );
  }

  @override
  SimulationState getState() {
    throw UnsupportedError(
      'IsolateSimulationEngine is not supported on web runtimes. '
      'Use DartSimulationEngine instead.',
    );
  }

  @override
  Future<ScenarioModel> saveScenario() {
    throw UnsupportedError(
      'IsolateSimulationEngine is not supported on web runtimes. '
      'Use DartSimulationEngine instead.',
    );
  }

  @override
  Future<void> loadScenario(ScenarioModel scenario) {
    throw UnsupportedError(
      'IsolateSimulationEngine is not supported on web runtimes. '
      'Use DartSimulationEngine instead.',
    );
  }

  @override
  Future<SnapshotModel> snapshot() {
    throw UnsupportedError(
      'IsolateSimulationEngine is not supported on web runtimes. '
      'Use DartSimulationEngine instead.',
    );
  }

  @override
  Future<void> restoreSnapshot(SnapshotModel snapshot) {
    throw UnsupportedError(
      'IsolateSimulationEngine is not supported on web runtimes. '
      'Use DartSimulationEngine instead.',
    );
  }

  @override
  Future<void> dispose() async {}
}
