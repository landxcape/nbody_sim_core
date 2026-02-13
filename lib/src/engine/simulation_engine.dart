import '../model/engine_contract.dart';
import '../model/simulation_body.dart';
import '../model/simulation_config.dart';
import '../model/simulation_state.dart';

/// Common runtime interface implemented by all simulation backends.
abstract class SimulationEngine {
  /// Initializes engine state from a config and starting bodies.
  Future<void> initialize({
    required SimulationConfig config,
    required List<SimulationBody> bodies,
  });

  /// Applies a new simulation configuration.
  Future<void> setConfig(SimulationConfig config);

  /// Applies a body create/update/delete edit.
  Future<void> applyEdit(BodyEdit edit);

  /// Advances the simulation by [ticks].
  Future<StepSummary> step(int ticks);

  /// Returns current simulation state.
  SimulationState getState();

  /// Loads a complete scenario document.
  Future<void> loadScenario(ScenarioModel scenario);

  /// Saves current state as a scenario.
  Future<ScenarioModel> saveScenario();

  /// Creates a point-in-time snapshot.
  Future<SnapshotModel> snapshot();

  /// Restores simulation from a snapshot.
  Future<void> restoreSnapshot(SnapshotModel snapshot);

  /// Disposes engine resources.
  Future<void> dispose() async {}
}
