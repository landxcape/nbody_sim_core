import 'dart:convert';

import '../model/engine_contract.dart';
import '../model/simulation_body.dart';
import '../model/simulation_config.dart';
import '../model/simulation_state.dart';
import 'rust_ffi_bindings.dart';
import 'simulation_engine.dart';

class RustFfiSimulationEngine implements SimulationEngine {
  RustFfiSimulationEngine({String? libraryPath, RustFfiBindings? bindings})
    : _bindings = bindings ?? RustFfiBindings.open(libraryPath: libraryPath);

  final RustFfiBindings _bindings;

  int? _handle;
  SimulationState _state = SimulationState.empty;

  @override
  Future<void> initialize({
    required SimulationConfig config,
    required List<SimulationBody> bodies,
  }) async {
    final response = _bindings.initialize(
      configJson: jsonEncode(config.toJson()),
      bodiesJson: jsonEncode(
        bodies.map((body) => body.toJson()).toList(growable: false),
      ),
    );

    final handle = (response['handle'] as num?)?.toInt();
    if (handle == null) {
      throw StateError('Native initialize response missing handle');
    }

    final stateJson = (response['state'] as Map).cast<String, dynamic>();
    _handle = handle;
    _state = SimulationState.fromJson(stateJson);
  }

  @override
  Future<void> setConfig(SimulationConfig config) async {
    final response = _bindings.setConfig(
      handle: _requireHandle(),
      configJson: jsonEncode(config.toJson()),
    );
    _state = SimulationState.fromJson(
      (response['state'] as Map).cast<String, dynamic>(),
    );
  }

  @override
  Future<void> applyEdit(BodyEdit edit) async {
    final response = _bindings.applyEdit(
      handle: _requireHandle(),
      editJson: jsonEncode(bodyEditToJson(edit)),
    );
    _state = SimulationState.fromJson(
      (response['state'] as Map).cast<String, dynamic>(),
    );
  }

  @override
  Future<StepSummary> step(int ticks) async {
    final response = _bindings.step(handle: _requireHandle(), ticks: ticks);
    _state = SimulationState.fromJson(
      (response['state'] as Map).cast<String, dynamic>(),
    );
    return StepSummary.fromJson(
      (response['summary'] as Map).cast<String, dynamic>(),
    );
  }

  @override
  SimulationState getState() => _state;

  @override
  Future<void> loadScenario(ScenarioModel scenario) async {
    final response = _bindings.loadScenario(
      handle: _requireHandle(),
      scenarioJson: jsonEncode(scenario.toJson()),
    );
    _state = SimulationState.fromJson(
      (response['state'] as Map).cast<String, dynamic>(),
    );
  }

  @override
  Future<ScenarioModel> saveScenario() async {
    final response = _bindings.saveScenario(handle: _requireHandle());
    return ScenarioModel.fromJson(
      (response['scenario'] as Map).cast<String, dynamic>(),
    );
  }

  @override
  Future<SnapshotModel> snapshot() async {
    final response = _bindings.snapshot(handle: _requireHandle());
    return SnapshotModel.fromJson(
      (response['snapshot'] as Map).cast<String, dynamic>(),
    );
  }

  @override
  Future<void> restoreSnapshot(SnapshotModel snapshot) async {
    final response = _bindings.restoreSnapshot(
      handle: _requireHandle(),
      snapshotJson: jsonEncode(snapshot.toJson()),
    );
    _state = SimulationState.fromJson(
      (response['state'] as Map).cast<String, dynamic>(),
    );
  }

  @override
  Future<void> dispose() async {
    final handle = _handle;
    if (handle == null) {
      return;
    }

    _bindings.disposeEngine(handle);
    _handle = null;
  }

  int _requireHandle() {
    final handle = _handle;
    if (handle == null) {
      throw StateError('Rust engine has not been initialized');
    }
    return handle;
  }
}
