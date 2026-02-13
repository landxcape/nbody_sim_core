import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

typedef _GsInitializeNative =
    Pointer<Utf8> Function(Pointer<Utf8> configJson, Pointer<Utf8> bodiesJson);
typedef _GsInitializeDart =
    Pointer<Utf8> Function(Pointer<Utf8> configJson, Pointer<Utf8> bodiesJson);

typedef _GsDisposeNative = Pointer<Utf8> Function(Uint64 handle);
typedef _GsDisposeDart = Pointer<Utf8> Function(int handle);

typedef _GsSetConfigNative =
    Pointer<Utf8> Function(Uint64 handle, Pointer<Utf8> configJson);
typedef _GsSetConfigDart =
    Pointer<Utf8> Function(int handle, Pointer<Utf8> configJson);

typedef _GsApplyEditNative =
    Pointer<Utf8> Function(Uint64 handle, Pointer<Utf8> editJson);
typedef _GsApplyEditDart =
    Pointer<Utf8> Function(int handle, Pointer<Utf8> editJson);

typedef _GsStepNative = Pointer<Utf8> Function(Uint64 handle, Uint32 ticks);
typedef _GsStepDart = Pointer<Utf8> Function(int handle, int ticks);

typedef _GsGetStateNative = Pointer<Utf8> Function(Uint64 handle);
typedef _GsGetStateDart = Pointer<Utf8> Function(int handle);

typedef _GsLoadScenarioNative =
    Pointer<Utf8> Function(Uint64 handle, Pointer<Utf8> scenarioJson);
typedef _GsLoadScenarioDart =
    Pointer<Utf8> Function(int handle, Pointer<Utf8> scenarioJson);

typedef _GsSaveScenarioNative = Pointer<Utf8> Function(Uint64 handle);
typedef _GsSaveScenarioDart = Pointer<Utf8> Function(int handle);

typedef _GsSnapshotNative = Pointer<Utf8> Function(Uint64 handle);
typedef _GsSnapshotDart = Pointer<Utf8> Function(int handle);

typedef _GsRestoreSnapshotNative =
    Pointer<Utf8> Function(Uint64 handle, Pointer<Utf8> snapshotJson);
typedef _GsRestoreSnapshotDart =
    Pointer<Utf8> Function(int handle, Pointer<Utf8> snapshotJson);

typedef _GsStringFreeNative = Void Function(Pointer<Utf8> value);
typedef _GsStringFreeDart = void Function(Pointer<Utf8> value);

class RustFfiBindings {
  RustFfiBindings._(DynamicLibrary library)
    : _initialize = library
          .lookupFunction<_GsInitializeNative, _GsInitializeDart>(
            'gs_initialize',
          ),
      _dispose = library.lookupFunction<_GsDisposeNative, _GsDisposeDart>(
        'gs_dispose',
      ),
      _setConfig = library.lookupFunction<_GsSetConfigNative, _GsSetConfigDart>(
        'gs_set_config',
      ),
      _applyEdit = library.lookupFunction<_GsApplyEditNative, _GsApplyEditDart>(
        'gs_apply_edit',
      ),
      _step = library.lookupFunction<_GsStepNative, _GsStepDart>('gs_step'),
      _getState = library.lookupFunction<_GsGetStateNative, _GsGetStateDart>(
        'gs_get_state',
      ),
      _loadScenario = library
          .lookupFunction<_GsLoadScenarioNative, _GsLoadScenarioDart>(
            'gs_load_scenario',
          ),
      _saveScenario = library
          .lookupFunction<_GsSaveScenarioNative, _GsSaveScenarioDart>(
            'gs_save_scenario',
          ),
      _snapshot = library.lookupFunction<_GsSnapshotNative, _GsSnapshotDart>(
        'gs_snapshot',
      ),
      _restoreSnapshot = library
          .lookupFunction<_GsRestoreSnapshotNative, _GsRestoreSnapshotDart>(
            'gs_restore_snapshot',
          ),
      _stringFree = library
          .lookupFunction<_GsStringFreeNative, _GsStringFreeDart>(
            'gs_string_free',
          );

  factory RustFfiBindings.open({String? libraryPath}) {
    final dynamicLibrary = _openDynamicLibrary(libraryPath: libraryPath);
    return RustFfiBindings._(dynamicLibrary);
  }

  final _GsInitializeDart _initialize;
  final _GsDisposeDart _dispose;
  final _GsSetConfigDart _setConfig;
  final _GsApplyEditDart _applyEdit;
  final _GsStepDart _step;
  final _GsGetStateDart _getState;
  final _GsLoadScenarioDart _loadScenario;
  final _GsSaveScenarioDart _saveScenario;
  final _GsSnapshotDart _snapshot;
  final _GsRestoreSnapshotDart _restoreSnapshot;
  final _GsStringFreeDart _stringFree;

  Map<String, dynamic> initialize({
    required String configJson,
    required String bodiesJson,
  }) {
    final configPtr = configJson.toNativeUtf8();
    final bodiesPtr = bodiesJson.toNativeUtf8();

    try {
      final response = _initialize(configPtr, bodiesPtr);
      return _decodeDataResponse(response);
    } finally {
      malloc.free(configPtr);
      malloc.free(bodiesPtr);
    }
  }

  Map<String, dynamic> disposeEngine(int handle) {
    final response = _dispose(handle);
    return _decodeDataResponse(response);
  }

  Map<String, dynamic> setConfig({
    required int handle,
    required String configJson,
  }) {
    final configPtr = configJson.toNativeUtf8();
    try {
      final response = _setConfig(handle, configPtr);
      return _decodeDataResponse(response);
    } finally {
      malloc.free(configPtr);
    }
  }

  Map<String, dynamic> applyEdit({
    required int handle,
    required String editJson,
  }) {
    final editPtr = editJson.toNativeUtf8();
    try {
      final response = _applyEdit(handle, editPtr);
      return _decodeDataResponse(response);
    } finally {
      malloc.free(editPtr);
    }
  }

  Map<String, dynamic> step({required int handle, required int ticks}) {
    final response = _step(handle, ticks);
    return _decodeDataResponse(response);
  }

  Map<String, dynamic> getState({required int handle}) {
    final response = _getState(handle);
    return _decodeDataResponse(response);
  }

  Map<String, dynamic> loadScenario({
    required int handle,
    required String scenarioJson,
  }) {
    final scenarioPtr = scenarioJson.toNativeUtf8();
    try {
      final response = _loadScenario(handle, scenarioPtr);
      return _decodeDataResponse(response);
    } finally {
      malloc.free(scenarioPtr);
    }
  }

  Map<String, dynamic> saveScenario({required int handle}) {
    final response = _saveScenario(handle);
    return _decodeDataResponse(response);
  }

  Map<String, dynamic> snapshot({required int handle}) {
    final response = _snapshot(handle);
    return _decodeDataResponse(response);
  }

  Map<String, dynamic> restoreSnapshot({
    required int handle,
    required String snapshotJson,
  }) {
    final snapshotPtr = snapshotJson.toNativeUtf8();
    try {
      final response = _restoreSnapshot(handle, snapshotPtr);
      return _decodeDataResponse(response);
    } finally {
      malloc.free(snapshotPtr);
    }
  }

  Map<String, dynamic> _decodeDataResponse(Pointer<Utf8> responsePointer) {
    final root = _decodeResponse(responsePointer);
    final data = root['data'];
    if (data is! Map) {
      throw StateError('Invalid response payload: missing data map');
    }
    return data.cast<String, dynamic>();
  }

  Map<String, dynamic> _decodeResponse(Pointer<Utf8> responsePointer) {
    if (responsePointer.address == 0) {
      throw StateError('Native response pointer was null');
    }

    try {
      final responseJson = responsePointer.toDartString();
      final decoded = jsonDecode(responseJson);
      if (decoded is! Map) {
        throw StateError('Invalid native response shape');
      }

      final response = decoded.cast<String, dynamic>();
      final ok = response['ok'] == true;
      if (!ok) {
        throw StateError(
          response['error']?.toString() ?? 'Unknown native error',
        );
      }

      return response;
    } finally {
      _stringFree(responsePointer);
    }
  }

  static DynamicLibrary _openDynamicLibrary({String? libraryPath}) {
    final attempts = <String>[];
    final candidates = _candidateLibraryPaths(libraryPath);

    for (final candidate in candidates) {
      try {
        return DynamicLibrary.open(candidate);
      } catch (_) {
        attempts.add(candidate);
      }
    }

    throw StateError(
      'Unable to open gravity engine dynamic library. Attempts: ${attempts.join(', ')}',
    );
  }

  static List<String> _candidateLibraryPaths(String? explicitPath) {
    final fileName = _libraryFileName();
    final candidates = <String>[];

    if (explicitPath != null && explicitPath.isNotEmpty) {
      candidates.add(explicitPath);
    }

    final envPath = Platform.environment['GRAVITY_ENGINE_LIB'];
    if (envPath != null && envPath.isNotEmpty) {
      candidates.add(envPath);
    }

    final cwd = Directory.current.path;
    candidates.add('$cwd/native/$fileName');
    candidates.add('$cwd/rust/gravity_engine/target/release/$fileName');
    candidates.add(fileName);

    return candidates.toSet().toList(growable: false);
  }

  static String _libraryFileName() {
    if (Platform.isMacOS) {
      return 'libgravity_engine.dylib';
    }
    if (Platform.isLinux) {
      return 'libgravity_engine.so';
    }
    if (Platform.isWindows) {
      return 'gravity_engine.dll';
    }

    throw UnsupportedError('Unsupported platform for Rust FFI engine');
  }
}
