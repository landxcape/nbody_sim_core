import 'package:nbody_sim_core/nbody_sim_core.dart';
import 'package:test/test.dart';

void main() {
  test('scenario validation accepts valid minimal v1 scenario', () {
    final scenario = {
      'schemaVersion': '1.0',
      'metadata': {
        'name': 'Test',
        'createdAt': '2026-01-01T00:00:00Z',
        'tags': <String>[],
      },
      'engineConfig': SimulationConfig.scientificDefault.toJson(),
      'bodies': <Map<String, dynamic>>[
        const SimulationBody(
          id: 'body-1',
          mass: 1,
          radius: 1,
          position: Vec2.zero,
          velocity: Vec2.zero,
          colorValue: 0xFFFFFFFF,
        ).toJson(),
      ],
    };

    final issues = ScenarioSchemaValidator.validateScenarioJson(scenario);
    expect(issues, isEmpty);
  });
}
