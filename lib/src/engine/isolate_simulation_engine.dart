import 'dart:async';
import 'dart:isolate';

import '../model/engine_contract.dart';
import '../model/simulation_body.dart';
import '../model/simulation_config.dart';
import '../model/simulation_state.dart';
import 'dart_simulation_engine.dart';
import 'rust_ffi_simulation_engine.dart';
import 'simulation_engine.dart';

enum EngineBackend { auto, rust, dart }

class IsolateSimulationEngine implements SimulationEngine {
  IsolateSimulationEngine({
    this.backend = EngineBackend.auto,
    this.rustLibraryPath,
  });

  final EngineBackend backend;
  final String? rustLibraryPath;

  Isolate? _isolate;
  ReceivePort? _receivePort;
  StreamSubscription<dynamic>? _receiveSubscription;
  SendPort? _workerSendPort;
  Future<void>? _startFuture;

  final Map<int, Completer<Map<String, dynamic>>> _pendingRequests = {};
  int _nextRequestId = 1;

  SimulationState _state = SimulationState.empty;
  bool _disposed = false;

  @override
  Future<void> initialize({
    required SimulationConfig config,
    required List<SimulationBody> bodies,
  }) async {
    final response = await _sendCommand('initialize', {
      'config': config.toJson(),
      'bodies': bodies.map((body) => body.toJson()).toList(growable: false),
    });

    _state = SimulationState.fromJson(
      (response['state'] as Map).cast<String, dynamic>(),
    );
  }

  @override
  Future<void> setConfig(SimulationConfig config) async {
    final response = await _sendCommand('setConfig', {
      'config': config.toJson(),
    });

    _state = SimulationState.fromJson(
      (response['state'] as Map).cast<String, dynamic>(),
    );
  }

  @override
  Future<void> applyEdit(BodyEdit edit) async {
    final response = await _sendCommand('applyEdit', {
      'edit': bodyEditToJson(edit),
    });

    _state = SimulationState.fromJson(
      (response['state'] as Map).cast<String, dynamic>(),
    );
  }

  @override
  Future<StepSummary> step(int ticks) async {
    final response = await _sendCommand('step', {'ticks': ticks});

    _state = SimulationState.fromJson(
      (response['state'] as Map).cast<String, dynamic>(),
    );
    return StepSummary.fromJson(
      (response['summary'] as Map).cast<String, dynamic>(),
    );
  }

  @override
  SimulationState getState() => _state;

  @override
  Future<void> loadScenario(ScenarioModel scenario) async {
    final response = await _sendCommand('loadScenario', {
      'scenario': scenario.toJson(),
    });

    _state = SimulationState.fromJson(
      (response['state'] as Map).cast<String, dynamic>(),
    );
  }

  @override
  Future<ScenarioModel> saveScenario() async {
    final response = await _sendCommand('saveScenario');
    return ScenarioModel.fromJson(
      (response['scenario'] as Map).cast<String, dynamic>(),
    );
  }

  @override
  Future<SnapshotModel> snapshot() async {
    final response = await _sendCommand('snapshot');
    return SnapshotModel.fromJson(
      (response['snapshot'] as Map).cast<String, dynamic>(),
    );
  }

  @override
  Future<void> restoreSnapshot(SnapshotModel snapshot) async {
    final response = await _sendCommand('restoreSnapshot', {
      'snapshot': snapshot.toJson(),
    });

    _state = SimulationState.fromJson(
      (response['state'] as Map).cast<String, dynamic>(),
    );
  }

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }

    if (_workerSendPort != null) {
      try {
        await _sendCommand('dispose');
      } catch (_) {
        // ignore cleanup failures during shutdown
      }
    }

    _disposed = true;

    for (final completer in _pendingRequests.values) {
      if (!completer.isCompleted) {
        completer.completeError(StateError('Engine disposed before response'));
      }
    }
    _pendingRequests.clear();

    await _receiveSubscription?.cancel();
    _receiveSubscription = null;

    _receivePort?.close();
    _receivePort = null;

    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _workerSendPort = null;
    _startFuture = null;
  }

  Future<Map<String, dynamic>> _sendCommand(
    String command, [
    Map<String, dynamic> payload = const {},
  ]) async {
    if (_disposed) {
      throw StateError('Engine already disposed');
    }

    await _ensureStarted();
    final sendPort = _workerSendPort;
    if (sendPort == null) {
      throw StateError('Worker isolate not ready');
    }

    final requestId = _nextRequestId++;
    final completer = Completer<Map<String, dynamic>>();
    _pendingRequests[requestId] = completer;

    sendPort.send({'id': requestId, 'command': command, 'payload': payload});

    return completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        _pendingRequests.remove(requestId);
        throw TimeoutException(
          'Timed out waiting for worker response: $command',
        );
      },
    );
  }

  Future<void> _ensureStarted() async {
    if (_workerSendPort != null) {
      return;
    }

    _startFuture ??= _startWorker();
    return _startFuture;
  }

  Future<void> _startWorker() async {
    final receivePort = ReceivePort();
    final readyCompleter = Completer<SendPort>();

    _receivePort = receivePort;
    _receiveSubscription = receivePort.listen((dynamic message) {
      if (message is! Map) {
        return;
      }

      final payload = message.cast<String, dynamic>();
      final type = payload['type'] as String?;

      if (type == 'ready') {
        final sendPort = payload['sendPort'];
        if (sendPort is SendPort && !readyCompleter.isCompleted) {
          readyCompleter.complete(sendPort);
        }
        return;
      }

      if (type == 'fatal') {
        if (!readyCompleter.isCompleted) {
          readyCompleter.completeError(
            StateError(payload['error']?.toString() ?? 'Worker startup failed'),
          );
        }
        return;
      }

      if (type == 'response') {
        final id = (payload['id'] as num?)?.toInt();
        if (id == null) {
          return;
        }

        final completer = _pendingRequests.remove(id);
        if (completer == null || completer.isCompleted) {
          return;
        }

        if (payload['ok'] == true) {
          final data =
              (payload['data'] as Map?)?.cast<String, dynamic>() ??
              const <String, dynamic>{};
          completer.complete(data);
          return;
        }

        completer.completeError(
          StateError(payload['error']?.toString() ?? 'Worker command failed'),
        );
      }
    });

    _isolate = await Isolate.spawn<Map<String, dynamic>>(_engineWorkerMain, {
      'sendPort': receivePort.sendPort,
      'backend': backend.name,
      'libraryPath': rustLibraryPath,
    }, debugName: 'simulation_engine_worker');

    _workerSendPort = await readyCompleter.future.timeout(
      const Duration(seconds: 10),
    );
  }
}

@pragma('vm:entry-point')
Future<void> _engineWorkerMain(Map<String, dynamic> args) async {
  final mainSendPort = args['sendPort'] as SendPort;
  final backendName = args['backend'] as String? ?? EngineBackend.auto.name;
  final libraryPath = args['libraryPath'] as String?;

  final receivePort = ReceivePort();
  late final SimulationEngine engine;
  var selectedBackend = EngineBackend.dart.name;

  try {
    switch (backendName) {
      case 'rust':
        engine = RustFfiSimulationEngine(libraryPath: libraryPath);
        selectedBackend = EngineBackend.rust.name;
        break;
      case 'auto':
        try {
          engine = RustFfiSimulationEngine(libraryPath: libraryPath);
          selectedBackend = EngineBackend.rust.name;
        } catch (_) {
          engine = DartSimulationEngine();
          selectedBackend = EngineBackend.dart.name;
        }
        break;
      case 'dart':
      default:
        engine = DartSimulationEngine();
        selectedBackend = EngineBackend.dart.name;
        break;
    }
  } catch (error) {
    mainSendPort.send({'type': 'fatal', 'error': error.toString()});
    receivePort.close();
    return;
  }

  mainSendPort.send({
    'type': 'ready',
    'sendPort': receivePort.sendPort,
    'backend': selectedBackend,
  });

  await for (final dynamic rawMessage in receivePort) {
    if (rawMessage is! Map) {
      continue;
    }

    final message = rawMessage.cast<String, dynamic>();
    final id = (message['id'] as num?)?.toInt();
    final command = message['command'] as String?;
    final payload =
        (message['payload'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};

    if (id == null || command == null) {
      continue;
    }

    try {
      final data = await _executeWorkerCommand(
        engine: engine,
        selectedBackend: selectedBackend,
        command: command,
        payload: payload,
      );

      mainSendPort.send({
        'type': 'response',
        'id': id,
        'ok': true,
        'data': data,
      });

      if (command == 'dispose') {
        break;
      }
    } catch (error) {
      mainSendPort.send({
        'type': 'response',
        'id': id,
        'ok': false,
        'error': error.toString(),
      });
    }
  }

  await engine.dispose();
  receivePort.close();
}

Future<Map<String, dynamic>> _executeWorkerCommand({
  required SimulationEngine engine,
  required String selectedBackend,
  required String command,
  required Map<String, dynamic> payload,
}) async {
  switch (command) {
    case 'initialize':
      await engine.initialize(
        config: SimulationConfig.fromJson(
          (payload['config'] as Map).cast<String, dynamic>(),
        ),
        bodies: ((payload['bodies'] as List?) ?? const [])
            .map(
              (item) => SimulationBody.fromJson(
                (item as Map).cast<String, dynamic>(),
              ),
            )
            .toList(growable: false),
      );
      return {'backend': selectedBackend, 'state': engine.getState().toJson()};

    case 'setConfig':
      await engine.setConfig(
        SimulationConfig.fromJson(
          (payload['config'] as Map).cast<String, dynamic>(),
        ),
      );
      return {'state': engine.getState().toJson()};

    case 'applyEdit':
      await engine.applyEdit(
        bodyEditFromJson((payload['edit'] as Map).cast<String, dynamic>()),
      );
      return {'state': engine.getState().toJson()};

    case 'step':
      final summary = await engine.step(
        (payload['ticks'] as num?)?.toInt() ?? 1,
      );
      return {'summary': summary.toJson(), 'state': engine.getState().toJson()};

    case 'loadScenario':
      await engine.loadScenario(
        ScenarioModel.fromJson(
          (payload['scenario'] as Map).cast<String, dynamic>(),
        ),
      );
      return {'state': engine.getState().toJson()};

    case 'saveScenario':
      final scenario = await engine.saveScenario();
      return {'scenario': scenario.toJson()};

    case 'snapshot':
      final snapshot = await engine.snapshot();
      return {'snapshot': snapshot.toJson()};

    case 'restoreSnapshot':
      await engine.restoreSnapshot(
        SnapshotModel.fromJson(
          (payload['snapshot'] as Map).cast<String, dynamic>(),
        ),
      );
      return {'state': engine.getState().toJson()};

    case 'dispose':
      return const <String, dynamic>{};

    default:
      throw StateError('Unknown worker command: $command');
  }
}
