import 'simulation_body.dart';
import 'simulation_config.dart';

/// Immutable simulation state snapshot.
class SimulationState {
  /// Creates a simulation state.
  const SimulationState({
    required this.tick,
    required this.simTime,
    required this.config,
    required this.bodies,
  });

  /// Current tick index.
  final int tick;

  /// Current simulation time.
  final double simTime;

  /// Active simulation config.
  final SimulationConfig config;

  /// Active bodies.
  final List<SimulationBody> bodies;

  /// Empty initial state constant.
  static SimulationState get empty {
    return const SimulationState(
      tick: 0,
      simTime: 0,
      config: SimulationConfig.scientificDefault,
      bodies: [],
    );
  }

  /// Serializes this state to JSON.
  Map<String, dynamic> toJson() {
    return {
      'tick': tick,
      'simTime': simTime,
      'config': config.toJson(),
      'bodies': bodies.map((body) => body.toJson()).toList(growable: false),
    };
  }

  /// Deserializes a state from JSON.
  factory SimulationState.fromJson(Map<String, dynamic> json) {
    final bodiesJson = (json['bodies'] as List?) ?? const [];

    return SimulationState(
      tick: (json['tick'] as num).toInt(),
      simTime: (json['simTime'] as num).toDouble(),
      config: SimulationConfig.fromJson(
        (json['config'] as Map).cast<String, dynamic>(),
      ),
      bodies: bodiesJson
          .map(
            (item) =>
                SimulationBody.fromJson((item as Map).cast<String, dynamic>()),
          )
          .toList(growable: false),
    );
  }
}
