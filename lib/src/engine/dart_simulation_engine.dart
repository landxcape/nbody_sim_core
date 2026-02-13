import 'dart:math' as math;

import '../model/engine_contract.dart';
import '../model/simulation_body.dart';
import '../model/simulation_config.dart';
import '../model/simulation_state.dart';
import '../model/vector2.dart';
import 'simulation_engine.dart';

class DartSimulationEngine implements SimulationEngine {
  SimulationConfig _config = SimulationConfig.scientificDefault;
  final List<SimulationBody> _bodies = [];
  int _tick = 0;
  double _simTime = 0;

  @override
  Future<void> initialize({
    required SimulationConfig config,
    required List<SimulationBody> bodies,
  }) async {
    _assertValidConfig(config);
    _assertValidBodies(bodies);
    _config = config;
    _bodies
      ..clear()
      ..addAll(_cloneBodies(bodies));
    _tick = 0;
    _simTime = 0;
  }

  @override
  Future<void> setConfig(SimulationConfig config) async {
    _assertValidConfig(config);
    _config = config;
  }

  @override
  Future<void> applyEdit(BodyEdit edit) async {
    if (edit is BodyCreate) {
      _createBody(edit.body);
      return;
    }

    if (edit is BodyUpdate) {
      _updateBody(edit);
      return;
    }

    if (edit is BodyDelete) {
      _deleteBody(edit.id);
      return;
    }

    throw StateError('Unsupported body edit type: ${edit.runtimeType}');
  }

  @override
  Future<StepSummary> step(int ticks) async {
    if (ticks <= 0) {
      return StepSummary(
        ticksApplied: 0,
        finalTick: _tick,
        simTime: _simTime,
        collisionEvents: 0,
        mergedEvents: 0,
        warnings: const [],
      );
    }

    final watch = Stopwatch()..start();
    var collisionEvents = 0;
    var mergedEvents = 0;
    var maxBodyCount = 0;

    for (var i = 0; i < ticks; i++) {
      final dtUsed = _integrateStep();
      final stats = _resolveCollisions();
      collisionEvents += stats.collisionEvents;
      mergedEvents += stats.mergedEvents;
      _tick += 1;
      _simTime += dtUsed;
      maxBodyCount = math.max(
        maxBodyCount,
        _bodies.where((body) => body.alive).length,
      );
      _assertFiniteBodies();
    }
    watch.stop();
    final elapsedMicros = watch.elapsedMicroseconds;

    return StepSummary(
      ticksApplied: ticks,
      finalTick: _tick,
      simTime: _simTime,
      collisionEvents: collisionEvents,
      mergedEvents: mergedEvents,
      warnings: const [],
      pairwiseTicks: ticks,
      barnesHutTicks: 0,
      stepWallTimeMicros: elapsedMicros,
      averageTickMicros: elapsedMicros ~/ ticks,
      maxBodyCount: maxBodyCount,
      lastSolverMode: 'pairwise',
    );
  }

  @override
  SimulationState getState() {
    return SimulationState(
      tick: _tick,
      simTime: _simTime,
      config: _config,
      bodies: List<SimulationBody>.unmodifiable(_cloneBodies(_bodies)),
    );
  }

  @override
  Future<void> loadScenario(ScenarioModel scenario) async {
    if (!scenario.schemaVersion.startsWith('1')) {
      throw StateError('Only schema version 1.x is supported');
    }
    _assertValidConfig(scenario.config);
    _assertValidBodies(scenario.bodies);

    _config = scenario.config;
    _bodies
      ..clear()
      ..addAll(_cloneBodies(scenario.bodies));
    _tick = 0;
    _simTime = 0;
  }

  @override
  Future<ScenarioModel> saveScenario() async {
    return ScenarioModel(
      schemaVersion: '1.0',
      name: 'Untitled',
      config: _config,
      bodies: _cloneBodies(_bodies),
    );
  }

  @override
  Future<SnapshotModel> snapshot() async {
    return SnapshotModel(
      schemaVersion: '1.0',
      tick: _tick,
      simTime: _simTime,
      configHash: _stableConfigHash(_config),
      bodies: _cloneBodies(_bodies),
    );
  }

  @override
  Future<void> restoreSnapshot(SnapshotModel snapshot) async {
    if (!snapshot.schemaVersion.startsWith('1')) {
      throw StateError('Only schema version 1.x is supported');
    }

    _assertValidBodies(snapshot.bodies);
    _tick = snapshot.tick;
    _simTime = snapshot.simTime;
    _bodies
      ..clear()
      ..addAll(_cloneBodies(snapshot.bodies));
  }

  @override
  Future<void> dispose() async {}

  double _integrateStep() {
    final dt = _effectiveDt();
    switch (_config.integrator) {
      case IntegratorKind.semiImplicitEuler:
        _semiImplicitEulerStep(dt);
        return dt;
      case IntegratorKind.velocityVerlet:
        _velocityVerletStep(dt);
        return dt;
      case IntegratorKind.rk4:
        _rk4Step(dt);
        return dt;
    }
  }

  double _effectiveDt() {
    if (_config.dtPolicy != DtPolicy.adaptive) {
      return _config.dt;
    }

    var maxSpeed = 0.0;
    for (final body in _bodies.where((body) => body.alive)) {
      maxSpeed = math.max(maxSpeed, body.velocity.norm);
    }

    var minDistance = double.infinity;
    for (var i = 0; i < _bodies.length; i++) {
      if (!_bodies[i].alive) {
        continue;
      }
      for (var j = i + 1; j < _bodies.length; j++) {
        if (!_bodies[j].alive) {
          continue;
        }
        final distance = (_bodies[j].position - _bodies[i].position).norm;
        if (distance > 0) {
          minDistance = math.min(minDistance, distance);
        }
      }
    }

    if (!minDistance.isFinite || maxSpeed <= 0) {
      return _config.dt;
    }

    final suggested = 0.05 * minDistance / maxSpeed;
    return suggested.clamp(_config.dt * 0.05, _config.dt);
  }

  void _semiImplicitEulerStep(double dt) {
    final accelerations = _computeAccelerations(_positions());
    for (var i = 0; i < _bodies.length; i++) {
      final body = _bodies[i];
      if (!body.alive) {
        continue;
      }
      final nextVelocity = body.velocity + (accelerations[i] * dt);
      final nextPosition = body.position + (nextVelocity * dt);
      _bodies[i] = body.copyWith(
        position: nextPosition,
        velocity: nextVelocity,
      );
    }
  }

  void _velocityVerletStep(double dt) {
    final p0 = _positions();
    final v0 = _velocities();
    final a0 = _computeAccelerations(p0);

    final predictedPositions = List<Vec2>.generate(_bodies.length, (i) {
      if (!_bodies[i].alive) {
        return p0[i];
      }
      return p0[i] + (v0[i] * dt) + (a0[i] * (0.5 * dt * dt));
    }, growable: false);

    final a1 = _computeAccelerations(predictedPositions);

    for (var i = 0; i < _bodies.length; i++) {
      final body = _bodies[i];
      if (!body.alive) {
        continue;
      }
      final nextVelocity = v0[i] + ((a0[i] + a1[i]) * (0.5 * dt));
      _bodies[i] = body.copyWith(
        position: predictedPositions[i],
        velocity: nextVelocity,
      );
    }
  }

  void _rk4Step(double dt) {
    final count = _bodies.length;
    final p0 = _positions();
    final v0 = _velocities();

    final k1v = _computeAccelerations(p0);
    final k1p = v0;

    final p2 = List<Vec2>.generate(
      count,
      (i) => p0[i] + (k1p[i] * (0.5 * dt)),
      growable: false,
    );
    final v2 = List<Vec2>.generate(
      count,
      (i) => v0[i] + (k1v[i] * (0.5 * dt)),
      growable: false,
    );

    final k2v = _computeAccelerations(p2);
    final k2p = v2;

    final p3 = List<Vec2>.generate(
      count,
      (i) => p0[i] + (k2p[i] * (0.5 * dt)),
      growable: false,
    );
    final v3 = List<Vec2>.generate(
      count,
      (i) => v0[i] + (k2v[i] * (0.5 * dt)),
      growable: false,
    );

    final k3v = _computeAccelerations(p3);
    final k3p = v3;

    final p4 = List<Vec2>.generate(
      count,
      (i) => p0[i] + (k3p[i] * dt),
      growable: false,
    );
    final v4 = List<Vec2>.generate(
      count,
      (i) => v0[i] + (k3v[i] * dt),
      growable: false,
    );

    final k4v = _computeAccelerations(p4);
    final k4p = v4;

    for (var i = 0; i < count; i++) {
      if (!_bodies[i].alive) {
        continue;
      }

      final dp = (k1p[i] + (k2p[i] * 2) + (k3p[i] * 2) + k4p[i]) * (dt / 6);
      final dv = (k1v[i] + (k2v[i] * 2) + (k3v[i] * 2) + k4v[i]) * (dt / 6);

      final body = _bodies[i];
      _bodies[i] = body.copyWith(
        position: body.position + dp,
        velocity: body.velocity + dv,
      );
    }
  }

  List<Vec2> _computeAccelerations(List<Vec2> positions) {
    final accelerations = List<Vec2>.generate(
      _bodies.length,
      (_) => Vec2.zero,
      growable: false,
    );
    final epsilon2 = _config.softeningEpsilon * _config.softeningEpsilon;

    for (var i = 0; i < _bodies.length; i++) {
      if (!_bodies[i].alive) {
        continue;
      }
      for (var j = i + 1; j < _bodies.length; j++) {
        if (!_bodies[j].alive) {
          continue;
        }

        final delta = positions[j] - positions[i];
        final distSq = delta.normSquared + epsilon2;
        if (distSq <= 0) {
          continue;
        }

        final invDist = 1 / math.sqrt(distSq);
        final invDist3 = invDist * invDist * invDist;
        final scale = _config.gravityConstant * invDist3;

        accelerations[i] =
            accelerations[i] + (delta * (scale * _bodies[j].mass));
        accelerations[j] =
            accelerations[j] - (delta * (scale * _bodies[i].mass));
      }
    }

    return accelerations;
  }

  _CollisionStats _resolveCollisions() {
    if (_config.collisionMode == CollisionMode.ignore) {
      return const _CollisionStats(collisionEvents: 0, mergedEvents: 0);
    }

    var collisionEvents = 0;
    var mergedEvents = 0;

    for (var i = 0; i < _bodies.length; i++) {
      if (!_bodies[i].alive) {
        continue;
      }
      for (var j = i + 1; j < _bodies.length; j++) {
        if (!_bodies[j].alive) {
          continue;
        }

        final delta = _bodies[j].position - _bodies[i].position;
        final distance = delta.norm;
        final collisionDistance = _bodies[i].radius + _bodies[j].radius;

        if (distance > collisionDistance) {
          continue;
        }

        collisionEvents += 1;

        switch (_config.collisionMode) {
          case CollisionMode.elastic:
            _applyElasticCollision(i, j, delta, distance, collisionDistance);
            break;
          case CollisionMode.inelasticMerge:
            _applyInelasticMerge(i, j);
            mergedEvents += 1;
            break;
          case CollisionMode.ignore:
            break;
        }
      }
    }

    if (_config.collisionMode == CollisionMode.inelasticMerge) {
      _bodies.removeWhere((body) => !body.alive);
    }

    return _CollisionStats(
      collisionEvents: collisionEvents,
      mergedEvents: mergedEvents,
    );
  }

  void _applyInelasticMerge(int i, int j) {
    final first = _bodies[i];
    final second = _bodies[j];
    if (!first.alive || !second.alive) {
      return;
    }

    final totalMass = first.mass + second.mass;
    if (totalMass <= 0) {
      return;
    }

    final mergedPosition =
        ((first.position * first.mass) + (second.position * second.mass)) /
        totalMass;
    final mergedVelocity =
        ((first.velocity * first.mass) + (second.velocity * second.mass)) /
        totalMass;
    final mergedRadius = math.sqrt(
      (first.radius * first.radius) + (second.radius * second.radius),
    );

    _bodies[i] = first.copyWith(
      mass: totalMass,
      position: mergedPosition,
      velocity: mergedVelocity,
      radius: mergedRadius,
    );
    _bodies[j] = second.copyWith(alive: false);
  }

  void _applyElasticCollision(
    int i,
    int j,
    Vec2 delta,
    double distance,
    double collisionDistance,
  ) {
    var first = _bodies[i];
    var second = _bodies[j];
    if (!first.alive || !second.alive) {
      return;
    }

    final normal = distance > 0 ? (delta / distance) : const Vec2(1, 0);

    final relativeVelocity = second.velocity - first.velocity;
    final velAlongNormal = relativeVelocity.dot(normal);

    var v1 = first.velocity;
    var v2 = second.velocity;

    if (velAlongNormal <= 0) {
      final inverseMassSum = (1 / first.mass) + (1 / second.mass);
      if (inverseMassSum > 0) {
        final impulseMagnitude = -2 * velAlongNormal / inverseMassSum;
        final impulse = normal * impulseMagnitude;
        v1 = v1 - (impulse / first.mass);
        v2 = v2 + (impulse / second.mass);
      }
    }

    var p1 = first.position;
    var p2 = second.position;

    final overlap = math.max(collisionDistance - distance, 0);
    if (overlap > 0) {
      final correction = normal * ((overlap * 0.5) + 1e-9);
      p1 = p1 - correction;
      p2 = p2 + correction;
    }

    first = first.copyWith(position: p1, velocity: v1);
    second = second.copyWith(position: p2, velocity: v2);

    _bodies[i] = first;
    _bodies[j] = second;
  }

  void _createBody(SimulationBody body) {
    _assertValidBody(body);
    if (_bodies.any((existing) => existing.id == body.id)) {
      throw StateError('Duplicate body id: ${body.id}');
    }
    _bodies.add(body);
  }

  void _updateBody(BodyUpdate update) {
    final index = _bodies.indexWhere((body) => body.id == update.id);
    if (index < 0) {
      throw StateError('Body not found: ${update.id}');
    }

    final body = _bodies[index];
    final next = body.copyWith(
      mass: update.mass,
      radius: update.radius,
      position: update.position,
      velocity: update.velocity,
      alive: update.alive,
      label: update.label,
      kind: update.kind,
      colorValue: update.colorValue,
    );

    _assertValidBody(next);
    _bodies[index] = next;
  }

  void _deleteBody(String id) {
    final initialLength = _bodies.length;
    _bodies.removeWhere((body) => body.id == id);
    if (_bodies.length == initialLength) {
      throw StateError('Body not found: $id');
    }
  }

  void _assertValidConfig(SimulationConfig config) {
    final error = config.validate();
    if (error != null) {
      throw StateError(error);
    }
  }

  void _assertValidBodies(List<SimulationBody> bodies) {
    final ids = <String>{};
    for (final body in bodies) {
      _assertValidBody(body);
      if (!ids.add(body.id)) {
        throw StateError('Duplicate body id: ${body.id}');
      }
    }
  }

  void _assertValidBody(SimulationBody body) {
    final error = body.validate();
    if (error != null) {
      throw StateError(error);
    }
  }

  void _assertFiniteBodies() {
    for (final body in _bodies.where((body) => body.alive)) {
      if (!body.position.isFinite || !body.velocity.isFinite) {
        throw StateError('Numerical instability detected on body ${body.id}');
      }
    }
  }

  List<Vec2> _positions() =>
      _bodies.map((body) => body.position).toList(growable: false);

  List<Vec2> _velocities() =>
      _bodies.map((body) => body.velocity).toList(growable: false);

  List<SimulationBody> _cloneBodies(List<SimulationBody> bodies) {
    return bodies.map((body) => body.copyWith()).toList(growable: false);
  }

  String _stableConfigHash(SimulationConfig config) {
    return [
      config.gravityConstant.toStringAsExponential(12),
      config.softeningEpsilon.toStringAsExponential(12),
      config.dt.toStringAsExponential(12),
      config.dtPolicy.name,
      config.integrator.name,
      config.collisionMode.name,
      config.deterministic.toString(),
      config.gravitySolver.name,
      config.barnesHutTheta.toStringAsExponential(12),
      config.barnesHutThreshold.toString(),
    ].join('|');
  }
}

class _CollisionStats {
  const _CollisionStats({
    required this.collisionEvents,
    required this.mergedEvents,
  });

  final int collisionEvents;
  final int mergedEvents;
}
