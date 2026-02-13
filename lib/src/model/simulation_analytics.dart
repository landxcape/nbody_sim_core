import 'vector2.dart';

class SimulationAnalytics {
  const SimulationAnalytics({
    required this.totalEnergy,
    required this.energyDriftRatio,
    required this.totalMomentum,
    required this.angularMomentum,
    required this.nearestApproach,
    required this.bodyCount,
    required this.tick,
    required this.simTime,
    required this.averageTickMicros,
    required this.lastSolverMode,
    required this.pairwiseTicks,
    required this.barnesHutTicks,
  });

  static const empty = SimulationAnalytics(
    totalEnergy: 0,
    energyDriftRatio: 0,
    totalMomentum: Vec2.zero,
    angularMomentum: 0,
    nearestApproach: 0,
    bodyCount: 0,
    tick: 0,
    simTime: 0,
    averageTickMicros: 0,
    lastSolverMode: 'pairwise',
    pairwiseTicks: 0,
    barnesHutTicks: 0,
  );

  final double totalEnergy;
  final double energyDriftRatio;
  final Vec2 totalMomentum;
  final double angularMomentum;
  final double nearestApproach;
  final int bodyCount;
  final int tick;
  final double simTime;
  final int averageTickMicros;
  final String lastSolverMode;
  final int pairwiseTicks;
  final int barnesHutTicks;
}
