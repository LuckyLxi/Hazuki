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
    facade.debug.softwareLogCaptureEnabled =
        prefs.getBool(SourcePrefsKeys.softwareLogCaptureEnabled) ?? false;
    if (!facade.softwareLogCaptureEnabled) {
      _clearCapturedLogs(facade);
    }
    return facade.softwareLogCaptureEnabled;
  }

  Future<void> setSoftwareLogCaptureEnabled(bool enabled) async {
    final facade = _facade;
    facade.debug.softwareLogCaptureEnabled = enabled;
    if (!enabled) {
      _clearCapturedLogs(facade);
    }
    final prefs = await facade.ensurePrefs();
    await prefs.setBool(SourcePrefsKeys.softwareLogCaptureEnabled, enabled);
  }

  void _clearCapturedLogs(HazukiSourceFacade facade) {
    facade.clearCapturedLogs();
    facade.lastLoginDebugInfo = null;
    facade.lastSourceVersionDebugInfo = null;
  }
}
