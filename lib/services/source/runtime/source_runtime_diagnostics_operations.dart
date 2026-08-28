import '../common/source_prefs_keys.dart';
import 'source_runtime_facade.dart';
import 'source_runtime_host.dart';

/// Owns runtime diagnostic logging and its persisted capture preference.
class SourceRuntimeDiagnosticsOperations {
  const SourceRuntimeDiagnosticsOperations({
    required SourceRuntimeHost runtimeHost,
  }) : _runtimeHost = runtimeHost;

  final SourceRuntimeHost _runtimeHost;

  HazukiSourceFacade get _facade => _runtimeHost.activeHandle.facade;

  void logRuntimeRetryRequested(String source) {
    final facade = _facade;
    facade.addApplicationLog(
      level: 'info',
      title: 'Source retry requested',
      source: 'source_runtime',
      content: {'trigger': source, ...facade.runtimeState.toDebugMap()},
    );
  }

  Future<bool> loadSoftwareLogCaptureEnabled() async {
    final facade = _facade;
    final prefs = await facade.ensurePrefs();
    final enabled =
        prefs.getBool(SourcePrefsKeys.softwareLogCaptureEnabled) ?? false;
    facade.debug.softwareLogCaptureEnabled = enabled;
    await _runtimeHost.logStore.initialize(captureEnabled: enabled);
    return enabled;
  }

  Future<void> setSoftwareLogCaptureEnabled(bool enabled) async {
    final facade = _facade;
    facade.debug.softwareLogCaptureEnabled = enabled;
    await _runtimeHost.logStore.setCaptureEnabled(enabled);
    if (!enabled) {
      facade.clearCapturedLogs();
    }
    final prefs = await facade.ensurePrefs();
    await prefs.setBool(SourcePrefsKeys.softwareLogCaptureEnabled, enabled);
  }
}
