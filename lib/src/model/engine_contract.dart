import 'simulation_body.dart';
import 'simulation_config.dart';
import 'vector2.dart';

sealed class BodyEdit {
  const BodyEdit();
}

class BodyCreate extends BodyEdit {
  const BodyCreate(this.body);

  final SimulationBody body;
}

class BodyUpdate extends BodyEdit {
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

  final String id;
  final double? mass;
  final double? radius;
  final Vec2? position;
  final Vec2? velocity;
  final bool? alive;
  final String? label;
  final String? kind;
  final int? colorValue;
}

class BodyDelete extends BodyEdit {
  const BodyDelete(this.id);

  final String id;
}

class StepSummary {
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

  final int ticksApplied;
  final int finalTick;
  final double simTime;
  final int collisionEvents;
  final int mergedEvents;
  final List<String> warnings;
  final int pairwiseTicks;
  final int barnesHutTicks;
  final int stepWallTimeMicros;
  final int averageTickMicros;
  final int maxBodyCount;
  final String lastSolverMode;

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

class ScenarioModel {
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

  final String schemaVersion;
  final String name;
  final SimulationConfig config;
  final List<SimulationBody> bodies;
  final String? description;
  final String? author;
  final String? createdAt;
  final List<String> tags;

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

class SnapshotModel {
  const SnapshotModel({
    required this.schemaVersion,
    required this.tick,
    required this.simTime,
    required this.configHash,
    required this.bodies,
    this.createdAt,
  });

  final String schemaVersion;
  final int tick;
  final double simTime;
  final String configHash;
  final List<SimulationBody> bodies;
  final String? createdAt;

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
