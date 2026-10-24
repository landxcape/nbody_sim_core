/// Platform fallback stub for [RustFfiBindings] on environments without `dart:ffi` (e.g. Web).
class RustFfiBindings {
  factory RustFfiBindings.open({String? libraryPath}) {
    throw UnsupportedError(
      'Rust FFI engine backend is not supported on web platforms. '
      'Use DartSimulationEngine instead.',
    );
  }

  Map<String, dynamic> initialize({
    required String configJson,
    required String bodiesJson,
  }) =>
      throw UnsupportedError('Rust FFI is not supported on web platforms.');

  Map<String, dynamic> disposeEngine(int handle) =>
      throw UnsupportedError('Rust FFI is not supported on web platforms.');

  Map<String, dynamic> setConfig({
    required int handle,
    required String configJson,
  }) =>
      throw UnsupportedError('Rust FFI is not supported on web platforms.');

  Map<String, dynamic> applyEdit({
    required int handle,
    required String editJson,
  }) =>
      throw UnsupportedError('Rust FFI is not supported on web platforms.');

  Map<String, dynamic> step({required int handle, required int ticks}) =>
      throw UnsupportedError('Rust FFI is not supported on web platforms.');

  Map<String, dynamic> getState({required int handle}) =>
      throw UnsupportedError('Rust FFI is not supported on web platforms.');

  Map<String, dynamic> loadScenario({
    required int handle,
    required String scenarioJson,
  }) =>
      throw UnsupportedError('Rust FFI is not supported on web platforms.');

  Map<String, dynamic> saveScenario({required int handle}) =>
      throw UnsupportedError('Rust FFI is not supported on web platforms.');

  Map<String, dynamic> snapshot({required int handle}) =>
      throw UnsupportedError('Rust FFI is not supported on web platforms.');

  Map<String, dynamic> restoreSnapshot({
    required int handle,
    required String snapshotJson,
  }) =>
      throw UnsupportedError('Rust FFI is not supported on web platforms.');
}
