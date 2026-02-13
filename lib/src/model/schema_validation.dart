import 'simulation_body.dart';
import 'simulation_config.dart';

class SchemaValidationIssue {
  const SchemaValidationIssue({required this.path, required this.message});

  final String path;
  final String message;

  @override
  String toString() => '$path: $message';
}

class ScenarioSchemaValidator {
  static List<SchemaValidationIssue> validateScenarioJson(
    Map<String, dynamic> json,
  ) {
    final issues = <SchemaValidationIssue>[];

    final version = json['schemaVersion'] as String?;
    if (version == null || version.isEmpty) {
      issues.add(
        const SchemaValidationIssue(
          path: 'schemaVersion',
          message: 'schemaVersion is required',
        ),
      );
    } else if (!version.startsWith('1.')) {
      issues.add(
        SchemaValidationIssue(
          path: 'schemaVersion',
          message: 'unsupported schemaVersion: $version',
        ),
      );
    }

    final metadata = json['metadata'];
    if (metadata is! Map) {
      issues.add(
        const SchemaValidationIssue(
          path: 'metadata',
          message: 'metadata object is required',
        ),
      );
    } else {
      final name = metadata['name']?.toString() ?? '';
      if (name.trim().isEmpty) {
        issues.add(
          const SchemaValidationIssue(
            path: 'metadata.name',
            message: 'name must not be empty',
          ),
        );
      }
      final createdAt = metadata['createdAt']?.toString() ?? '';
      if (createdAt.trim().isEmpty) {
        issues.add(
          const SchemaValidationIssue(
            path: 'metadata.createdAt',
            message: 'createdAt is required',
          ),
        );
      }
    }

    final configMap = json['engineConfig'];
    if (configMap is! Map) {
      issues.add(
        const SchemaValidationIssue(
          path: 'engineConfig',
          message: 'engineConfig object is required',
        ),
      );
    } else {
      try {
        final config = SimulationConfig.fromJson(
          configMap.cast<String, dynamic>(),
        );
        final configError = config.validate();
        if (configError != null) {
          issues.add(
            SchemaValidationIssue(path: 'engineConfig', message: configError),
          );
        }
      } catch (error) {
        issues.add(
          SchemaValidationIssue(
            path: 'engineConfig',
            message: 'invalid engineConfig: $error',
          ),
        );
      }
    }

    final bodies = json['bodies'];
    if (bodies is! List || bodies.isEmpty) {
      issues.add(
        const SchemaValidationIssue(
          path: 'bodies',
          message: 'at least one body is required',
        ),
      );
    } else {
      final ids = <String>{};
      for (var i = 0; i < bodies.length; i++) {
        final raw = bodies[i];
        if (raw is! Map) {
          issues.add(
            SchemaValidationIssue(
              path: 'bodies[$i]',
              message: 'body must be an object',
            ),
          );
          continue;
        }
        try {
          final body = SimulationBody.fromJson(raw.cast<String, dynamic>());
          final bodyError = body.validate();
          if (bodyError != null) {
            issues.add(
              SchemaValidationIssue(path: 'bodies[$i]', message: bodyError),
            );
          }
          if (!ids.add(body.id)) {
            issues.add(
              SchemaValidationIssue(
                path: 'bodies[$i].id',
                message: 'duplicate body id: ${body.id}',
              ),
            );
          }
        } catch (error) {
          issues.add(
            SchemaValidationIssue(
              path: 'bodies[$i]',
              message: 'invalid body payload: $error',
            ),
          );
        }
      }
    }

    return issues;
  }
}

class ScenarioSchemaMigrator {
  static Map<String, dynamic> migrateToLatest(Map<String, dynamic> raw) {
    final version = raw['schemaVersion']?.toString();
    if (version == null || version.startsWith('0.')) {
      return _migrateLegacyV0(raw);
    }
    if (version.startsWith('1.')) {
      return {...raw, 'schemaVersion': '1.0'};
    }
    return raw;
  }

  static Map<String, dynamic> _migrateLegacyV0(Map<String, dynamic> raw) {
    final now = DateTime.now().toUtc().toIso8601String();
    final metadata = raw['metadata'] is Map
        ? (raw['metadata'] as Map).cast<String, dynamic>()
        : <String, dynamic>{
            'name': raw['name']?.toString() ?? 'Imported Scenario',
            'description': raw['description']?.toString(),
            'author': raw['author']?.toString(),
            'createdAt': now,
            'tags': (raw['tags'] as List?) ?? const <String>[],
          };

    final config = raw['engineConfig'] is Map
        ? (raw['engineConfig'] as Map).cast<String, dynamic>()
        : raw['config'] is Map
        ? (raw['config'] as Map).cast<String, dynamic>()
        : <String, dynamic>{};

    final migrated = <String, dynamic>{
      'schemaVersion': '1.0',
      'metadata': {
        ...metadata,
        'name': metadata['name']?.toString().trim().isEmpty ?? true
            ? 'Imported Scenario'
            : metadata['name'],
        'createdAt': metadata['createdAt']?.toString() ?? now,
        'tags': (metadata['tags'] as List?) ?? const <String>[],
      },
      'engineConfig': _normalizeLegacyConfig(config),
      'bodies': (raw['bodies'] as List?) ?? const <dynamic>[],
    };

    return migrated;
  }

  static Map<String, dynamic> _normalizeLegacyConfig(Map<String, dynamic> raw) {
    return {
      'gravityConstant':
          (raw['gravityConstant'] ?? raw['gravity'] ?? 1.0) as num,
      'softeningEpsilon':
          (raw['softeningEpsilon'] ?? raw['epsilon'] ?? 1e-4) as num,
      'dt': (raw['dt'] ?? 0.005) as num,
      'dtPolicy': raw['dtPolicy']?.toString() ?? DtPolicy.fixed.name,
      'integrator':
          raw['integrator']?.toString() ?? IntegratorKind.velocityVerlet.name,
      'collisionMode':
          raw['collisionMode']?.toString() ?? CollisionMode.inelasticMerge.name,
      'deterministic': raw['deterministic'] as bool? ?? true,
      'gravitySolver':
          raw['gravitySolver']?.toString() ?? GravitySolver.auto.name,
      'barnesHutTheta': (raw['barnesHutTheta'] ?? 0.6) as num,
      'barnesHutThreshold': (raw['barnesHutThreshold'] ?? 256) as num,
    };
  }
}
