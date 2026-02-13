import 'simulation_body.dart';
import 'simulation_config.dart';
import 'vector2.dart';

/// Base type for runtime body edit operations.
sealed class BodyEdit {
  /// Creates a body edit marker.
  const BodyEdit();
}

/// Adds a new body to the simulation.
class BodyCreate extends BodyEdit {
  /// Creates a body-creation edit.
  const BodyCreate(this.body);

  /// Body payload to insert into the active simulation state.
  final SimulationBody body;
}

/// Updates one or more properties of an existing body.
class BodyUpdate extends BodyEdit {
  /// Creates a body-update edit.
  const BodyUpdate({
    required this.id,
    this.mass,
    this.radius,
    this.position,
    this.velocity,
    this.alive,
    this.label,
    this.kind,
    this.colorValue,
  });

  /// Identifier of the body to modify.
  final String id;

  /// Optional updated mass value.
  final double? mass;

  /// Optional updated radius value.
  final double? radius;

  /// Optional updated position.
  final Vec2? position;

  /// Optional updated velocity.
  final Vec2? velocity;

  /// Optional alive/dead flag.
  final bool? alive;

  /// Optional human-readable label.
  final String? label;

  /// Optional body kind/category tag.
  final String? kind;

  /// Optional ARGB color value.
  final int? colorValue;
}

/// Removes a body from the simulation.
class BodyDelete extends BodyEdit {
  /// Creates a body-delete edit.
  const BodyDelete(this.id);

  /// Identifier of the body to remove.
  final String id;
}

/// Aggregated telemetry returned by a simulation stepping call.
class StepSummary {
  /// Creates a step summary payload.
  const StepSummary({
    required this.ticksApplied,
    required this.finalTick,
    required this.simTime,
    required this.collisionEvents,
    required this.mergedEvents,
    required this.warnings,
    this.pairwiseTicks = 0,
    this.barnesHutTicks = 0,
    this.stepWallTimeMicros = 0,
    this.averageTickMicros = 0,
    this.maxBodyCount = 0,
    this.lastSolverMode = 'pairwise',
  });

  /// Number of ticks applied for this step call.
  final int ticksApplied;

  /// Final simulation tick after applying the step.
  final int finalTick;

  /// Final simulation time after applying the step.
  final double simTime;

  /// Number of collision events detected.
  final int collisionEvents;

  /// Number of merge events applied.
  final int mergedEvents;

  /// Runtime warnings produced while stepping.
  final List<String> warnings;

  /// Number of ticks evaluated with pairwise solver.
  final int pairwiseTicks;

  /// Number of ticks evaluated with Barnes-Hut solver.
  final int barnesHutTicks;

  /// Total wall time in microseconds for this step call.
  final int stepWallTimeMicros;

  /// Average tick cost in microseconds.
  final int averageTickMicros;

  /// Maximum body count seen during this step call.
  final int maxBodyCount;

  /// Last solver mode used (`pairwise` or `barnes_hut` style value).
  final String lastSolverMode;

  /// Serializes this summary to JSON.
  Map<String, dynamic> toJson() {
    return {
      'ticksApplied': ticksApplied,
      'finalTick': finalTick,
      'simTime': simTime,
      'collisionEvents': collisionEvents,
      'mergedEvents': mergedEvents,
      'warnings': warnings,
      'pairwiseTicks': pairwiseTicks,
      'barnesHutTicks': barnesHutTicks,
      'stepWallTimeMicros': stepWallTimeMicros,
      'averageTickMicros': averageTickMicros,
      'maxBodyCount': maxBodyCount,
      'lastSolverMode': lastSolverMode,
    };
  }

  /// Deserializes a step summary from JSON.
  factory StepSummary.fromJson(Map<String, dynamic> json) {
    final warningsJson = (json['warnings'] as List?) ?? const [];
    return StepSummary(
      ticksApplied: (json['ticksApplied'] as num).toInt(),
      finalTick: (json['finalTick'] as num).toInt(),
      simTime: (json['simTime'] as num).toDouble(),
      collisionEvents: (json['collisionEvents'] as num).toInt(),
      mergedEvents: (json['mergedEvents'] as num).toInt(),
      warnings: warningsJson
          .map((item) => item.toString())
          .toList(growable: false),
      pairwiseTicks: (json['pairwiseTicks'] as num?)?.toInt() ?? 0,
      barnesHutTicks: (json['barnesHutTicks'] as num?)?.toInt() ?? 0,
      stepWallTimeMicros: (json['stepWallTimeMicros'] as num?)?.toInt() ?? 0,
      averageTickMicros: (json['averageTickMicros'] as num?)?.toInt() ?? 0,
      maxBodyCount: (json['maxBodyCount'] as num?)?.toInt() ?? 0,
      lastSolverMode: json['lastSolverMode']?.toString() ?? 'pairwise',
    );
  }
}

/// Portable scenario document used for save/load operations.
class ScenarioModel {
  /// Creates a scenario model.
  const ScenarioModel({
    required this.schemaVersion,
    required this.name,
    required this.config,
    required this.bodies,
    this.description,
    this.author,
    this.createdAt,
    this.tags = const [],
  });

  /// Scenario schema version.
  final String schemaVersion;

  /// Display name of the scenario.
  final String name;

  /// Engine configuration used by the scenario.
  final SimulationConfig config;

  /// Bodies included in the scenario.
  final List<SimulationBody> bodies;

  /// Optional description text.
  final String? description;

  /// Optional author string.
  final String? author;

  /// Optional creation timestamp.
  final String? createdAt;

  /// Optional tag collection for categorization.
  final List<String> tags;

  /// Serializes this scenario to JSON.
  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': schemaVersion,
      'metadata': {
        'name': name,
        'description': description,
        'author': author,
        'createdAt': createdAt ?? '1970-01-01T00:00:00Z',
        'tags': tags,
      },
      'engineConfig': config.toJson(),
      'bodies': bodies.map((body) => body.toJson()).toList(growable: false),
    };
  }

  /// Deserializes a scenario from JSON.
  factory ScenarioModel.fromJson(Map<String, dynamic> json) {
    final metadata =
        (json['metadata'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{'name': 'Untitled'};
    final bodiesJson = (json['bodies'] as List?) ?? const [];

    return ScenarioModel(
      schemaVersion: json['schemaVersion'] as String? ?? '1.0',
      name: metadata['name'] as String? ?? 'Untitled',
      description: metadata['description'] as String?,
      author: metadata['author'] as String?,
      createdAt: metadata['createdAt'] as String?,
      tags: ((metadata['tags'] as List?) ?? const [])
          .map((item) => item.toString())
          .toList(growable: false),
      config: SimulationConfig.fromJson(
        (json['engineConfig'] as Map).cast<String, dynamic>(),
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

/// Point-in-time snapshot payload used for restore/replay workflows.
class SnapshotModel {
  /// Creates a snapshot model.
  const SnapshotModel({
    required this.schemaVersion,
    required this.tick,
    required this.simTime,
    required this.configHash,
    required this.bodies,
    this.createdAt,
  });

  /// Snapshot schema version.
  final String schemaVersion;

  /// Tick captured by this snapshot.
  final int tick;

  /// Simulation time captured by this snapshot.
  final double simTime;

  /// Hash string representing the config used to produce this snapshot.
  final String configHash;

  /// Body collection captured in this snapshot.
  final List<SimulationBody> bodies;

  /// Optional timestamp when snapshot was created.
  final String? createdAt;

  /// Serializes this snapshot to JSON.
  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': schemaVersion,
      'createdAt': createdAt ?? '1970-01-01T00:00:00Z',
      'tick': tick,
      'simTime': simTime,
      'configHash': configHash,
      'bodies': bodies.map((body) => body.toJson()).toList(growable: false),
    };
  }

  /// Deserializes a snapshot from JSON.
  factory SnapshotModel.fromJson(Map<String, dynamic> json) {
    final bodiesJson = (json['bodies'] as List?) ?? const [];

    return SnapshotModel(
      schemaVersion: json['schemaVersion'] as String? ?? '1.0',
      createdAt: json['createdAt'] as String?,
      tick: (json['tick'] as num).toInt(),
      simTime: (json['simTime'] as num).toDouble(),
      configHash: json['configHash'] as String,
      bodies: bodiesJson
          .map(
            (item) =>
                SimulationBody.fromJson((item as Map).cast<String, dynamic>()),
          )
          .toList(growable: false),
    );
  }
}

/// Converts a [BodyEdit] polymorphic value into transport JSON.
Map<String, dynamic> bodyEditToJson(BodyEdit edit) {
  if (edit is BodyCreate) {
    return {'create': edit.body.toJson()};
  }

  if (edit is BodyUpdate) {
    Map<String, dynamic>? metadata;
    if (edit.label != null || edit.kind != null || edit.colorValue != null) {
      metadata = <String, dynamic>{};
      if (edit.label != null) {
        metadata['label'] = edit.label;
      }
      if (edit.kind != null) {
        metadata['kind'] = edit.kind;
      }
      if (edit.colorValue != null) {
        metadata['color'] = _toHexColor(edit.colorValue!);
      }
    }

    return {
      'update': {
        'id': edit.id,
        'mass': edit.mass,
        'radius': edit.radius,
        'position': edit.position?.toJson(),
        'velocity': edit.velocity?.toJson(),
        'alive': edit.alive,
        'metadata': metadata,
      }..removeWhere((key, value) => value == null),
    };
  }

  if (edit is BodyDelete) {
    return {
      'delete': {'id': edit.id},
    };
  }

  throw StateError('Unsupported body edit type: ${edit.runtimeType}');
}

/// Parses a [BodyEdit] from transport JSON.
BodyEdit bodyEditFromJson(Map<String, dynamic> json) {
  if (json.containsKey('create')) {
    final payload = (json['create'] as Map).cast<String, dynamic>();
    return BodyCreate(SimulationBody.fromJson(payload));
  }

  if (json.containsKey('update')) {
    final payload = (json['update'] as Map).cast<String, dynamic>();
    return BodyUpdate(
      id: payload['id'] as String,
      mass: (payload['mass'] as num?)?.toDouble(),
      radius: (payload['radius'] as num?)?.toDouble(),
      position: payload['position'] == null
          ? null
          : Vec2.fromJson((payload['position'] as Map).cast<String, dynamic>()),
      velocity: payload['velocity'] == null
          ? null
          : Vec2.fromJson((payload['velocity'] as Map).cast<String, dynamic>()),
      alive: payload['alive'] as bool?,
      label: payload['metadata'] == null
          ? null
          : (payload['metadata'] as Map)['label'] as String?,
      kind: payload['metadata'] == null
          ? null
          : (payload['metadata'] as Map)['kind'] as String?,
      colorValue: payload['metadata'] == null
          ? null
          : _parseColorValue((payload['metadata'] as Map)['color'] as String?),
    );
  }

  if (json.containsKey('delete')) {
    final payload = (json['delete'] as Map).cast<String, dynamic>();
    return BodyDelete(payload['id'] as String);
  }

  throw StateError('Unsupported body edit json payload');
}

String _toHexColor(int value) {
  return '#${value.toRadixString(16).padLeft(8, '0')}';
}

int? _parseColorValue(String? value) {
  if (value == null || value.isEmpty) {
    return null;
  }
  final normalized = value.startsWith('#') ? value.substring(1) : value;
  return int.tryParse(normalized, radix: 16);
}
