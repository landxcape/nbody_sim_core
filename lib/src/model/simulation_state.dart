import 'simulation_body.dart';
import 'simulation_config.dart';

class SimulationState {
  const SimulationState({
    required this.tick,
    required this.simTime,
    required this.config,
    required this.bodies,
  });

  final int tick;
  final double simTime;
  final SimulationConfig config;
  final List<SimulationBody> bodies;

  static SimulationState get empty {
    return const SimulationState(
      tick: 0,
      simTime: 0,
      config: SimulationConfig.scientificDefault,
      bodies: [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tick': tick,
      'simTime': simTime,
      'config': config.toJson(),
      'bodies': bodies.map((body) => body.toJson()).toList(growable: false),
    };
  }

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
