/// Supported integration algorithms for advancing simulation state.
enum IntegratorKind { semiImplicitEuler, velocityVerlet, rk4 }

/// Collision handling strategy.
enum CollisionMode { elastic, inelasticMerge, ignore }

/// Timestep policy for integration.
enum DtPolicy { fixed, adaptive }

/// Gravity solver mode.
enum GravitySolver { pairwise, barnesHut, auto }

/// Immutable runtime physics configuration.
class SimulationConfig {
  /// Creates a simulation configuration.
  const SimulationConfig({
    required this.gravityConstant,
    required this.softeningEpsilon,
    required this.dt,
    required this.dtPolicy,
    required this.integrator,
    required this.collisionMode,
    required this.deterministic,
    this.gravitySolver = GravitySolver.auto,
    this.barnesHutTheta = 0.6,
    this.barnesHutThreshold = 256,
  });

  /// Gravitational constant used in force computation.
  final double gravityConstant;

  /// Softening epsilon used to avoid singularities.
  final double softeningEpsilon;

  /// Base timestep size.
  final double dt;

  /// Timestep policy.
  final DtPolicy dtPolicy;

  /// Integration algorithm.
  final IntegratorKind integrator;

  /// Collision behavior mode.
  final CollisionMode collisionMode;

  /// Whether deterministic replay constraints are enabled.
  final bool deterministic;

  /// Solver mode selection.
  final GravitySolver gravitySolver;

  /// Barnes-Hut theta parameter.
  final double barnesHutTheta;

  /// Body-count threshold for Barnes-Hut switching.
  final int barnesHutThreshold;

  /// Predefined scientific default profile.
  static const scientificDefault = SimulationConfig(
    gravityConstant: 1,
    softeningEpsilon: 1e-4,
    dt: 0.005,
    dtPolicy: DtPolicy.fixed,
    integrator: IntegratorKind.velocityVerlet,
    collisionMode: CollisionMode.inelasticMerge,
    deterministic: true,
    gravitySolver: GravitySolver.auto,
    barnesHutTheta: 0.6,
    barnesHutThreshold: 256,
  );

  /// Returns a copy with the provided fields replaced.
  SimulationConfig copyWith({
    double? gravityConstant,
    double? softeningEpsilon,
    double? dt,
    DtPolicy? dtPolicy,
    IntegratorKind? integrator,
    CollisionMode? collisionMode,
    bool? deterministic,
    GravitySolver? gravitySolver,
    double? barnesHutTheta,
    int? barnesHutThreshold,
  }) {
    return SimulationConfig(
      gravityConstant: gravityConstant ?? this.gravityConstant,
      softeningEpsilon: softeningEpsilon ?? this.softeningEpsilon,
      dt: dt ?? this.dt,
      dtPolicy: dtPolicy ?? this.dtPolicy,
      integrator: integrator ?? this.integrator,
      collisionMode: collisionMode ?? this.collisionMode,
      deterministic: deterministic ?? this.deterministic,
      gravitySolver: gravitySolver ?? this.gravitySolver,
      barnesHutTheta: barnesHutTheta ?? this.barnesHutTheta,
      barnesHutThreshold: barnesHutThreshold ?? this.barnesHutThreshold,
    );
  }

  /// Validates config values and returns an error message if invalid.
  String? validate() {
    if (!gravityConstant.isFinite || gravityConstant <= 0) {
      return 'gravityConstant must be finite and > 0';
    }
    if (!softeningEpsilon.isFinite || softeningEpsilon < 0) {
      return 'softeningEpsilon must be finite and >= 0';
    }
    if (!dt.isFinite || dt <= 0) {
      return 'dt must be finite and > 0';
    }
    if (deterministic && dtPolicy == DtPolicy.adaptive) {
      return 'adaptive dt is not allowed in deterministic mode';
    }
    if (!barnesHutTheta.isFinite || barnesHutTheta <= 0 || barnesHutTheta > 2) {
      return 'barnesHutTheta must be finite and in (0, 2]';
    }
    if (barnesHutThreshold < 1) {
      return 'barnesHutThreshold must be >= 1';
    }
    return null;
  }

  /// Serializes this config to JSON.
  Map<String, dynamic> toJson() {
    return {
      'gravityConstant': gravityConstant,
      'softeningEpsilon': softeningEpsilon,
      'dt': dt,
      'dtPolicy': dtPolicy.name,
      'integrator': integrator.name,
      'collisionMode': collisionMode.name,
      'deterministic': deterministic,
      'gravitySolver': gravitySolver.name,
      'barnesHutTheta': barnesHutTheta,
      'barnesHutThreshold': barnesHutThreshold,
    };
  }

  /// Deserializes a config from JSON.
  factory SimulationConfig.fromJson(Map<String, dynamic> json) {
    return SimulationConfig(
      gravityConstant: (json['gravityConstant'] as num).toDouble(),
      softeningEpsilon: (json['softeningEpsilon'] as num).toDouble(),
      dt: (json['dt'] as num).toDouble(),
      dtPolicy: _parseDtPolicy(json['dtPolicy'] as String),
      integrator: _parseIntegrator(json['integrator'] as String),
      collisionMode: _parseCollisionMode(json['collisionMode'] as String),
      deterministic: json['deterministic'] as bool? ?? true,
      gravitySolver: _parseGravitySolver(json['gravitySolver'] as String?),
      barnesHutTheta: (json['barnesHutTheta'] as num?)?.toDouble() ?? 0.6,
      barnesHutThreshold: (json['barnesHutThreshold'] as num?)?.toInt() ?? 256,
    );
  }

  static IntegratorKind _parseIntegrator(String value) {
    return IntegratorKind.values.firstWhere(
      (item) => item.name == value,
      orElse: () => IntegratorKind.velocityVerlet,
    );
  }

  static CollisionMode _parseCollisionMode(String value) {
    return CollisionMode.values.firstWhere(
      (item) => item.name == value,
      orElse: () => CollisionMode.inelasticMerge,
    );
  }

  static DtPolicy _parseDtPolicy(String value) {
    return DtPolicy.values.firstWhere(
      (item) => item.name == value,
      orElse: () => DtPolicy.fixed,
    );
  }

  static GravitySolver _parseGravitySolver(String? value) {
    if (value == null || value.isEmpty) {
      return GravitySolver.auto;
    }
    return GravitySolver.values.firstWhere(
      (item) => item.name == value,
      orElse: () => GravitySolver.auto,
    );
  }
}
