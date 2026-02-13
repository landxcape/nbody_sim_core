import 'package:nbody_sim_core/nbody_sim_core.dart';

Future<void> main() async {
  final engine = DartSimulationEngine();
  await engine.initialize(
    config: SimulationConfig.scientificDefault,
    bodies: const [],
  );
  await engine.step(1);
  final snapshot = await engine.snapshot();
  await engine.restoreSnapshot(snapshot);
  await engine.dispose();
}
