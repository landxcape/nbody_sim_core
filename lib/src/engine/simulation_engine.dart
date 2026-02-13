import '../model/engine_contract.dart';
import '../model/simulation_body.dart';
import '../model/simulation_config.dart';
import '../model/simulation_state.dart';

abstract class SimulationEngine {
  Future<void> initialize({
    required SimulationConfig config,
    required List<SimulationBody> bodies,
  });

  Future<void> setConfig(SimulationConfig config);

  Future<void> applyEdit(BodyEdit edit);

  Future<StepSummary> step(int ticks);

  SimulationState getState();

  Future<void> loadScenario(ScenarioModel scenario);

  Future<ScenarioModel> saveScenario();

  Future<SnapshotModel> snapshot();

  Future<void> restoreSnapshot(SnapshotModel snapshot);

  Future<void> dispose() async {}
}
