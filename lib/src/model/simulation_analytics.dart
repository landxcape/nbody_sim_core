import 'vector2.dart';

/// Aggregated simulation metrics for diagnostics and telemetry.
class SimulationAnalytics {
  /// Creates an analytics payload.
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

  /// Empty analytics baseline.
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

  /// Total system energy.
  final double totalEnergy;

  /// Relative energy drift ratio.
  final double energyDriftRatio;

  /// Total linear momentum vector.
  final Vec2 totalMomentum;

  /// Total angular momentum scalar.
  final double angularMomentum;

  /// Smallest pairwise distance observed.
  final double nearestApproach;

  /// Current body count.
  final int bodyCount;

  /// Current tick.
  final int tick;

  /// Current simulation time.
  final double simTime;

  /// Average tick runtime in microseconds.
  final int averageTickMicros;

  /// Last solver mode used.
  final String lastSolverMode;

  /// Pairwise solver tick count.
  final int pairwiseTicks;

  /// Barnes-Hut solver tick count.
  final int barnesHutTicks;
}
