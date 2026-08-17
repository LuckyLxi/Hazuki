// The implementation below intentionally mirrors the complete interface.
// ignore_for_file: annotate_overrides

import '../models/source_contract_models.dart';
import 'source_runtime_diagnostics_operations.dart';
import 'source_runtime_initialization_operations.dart';
import 'source_runtime_recovery_operations.dart';
import 'source_script_editing_operations.dart';
import 'source_update_operations.dart';

/// Script storage, initialization, and update operations exposed to source
/// adapters. Keeping these forwards outside the composition root prevents the
/// root from becoming a second runtime API surface.
abstract interface class SourceRuntimeOperations {
  Future<void> init({
    void Function(int received, int total)? onSourceDownloadProgress,
    bool prewarm = false,
  });
  Future<void> ensureInitialized({String? sourceKey});
  Future<void> ensureSourceInitialized(String sourceKey);
  Future<void> prewarmInBackground();
  void logRuntimeRetryRequested(String source);
  Future<bool> loadSoftwareLogCaptureEnabled();
  Future<void> setSoftwareLogCaptureEnabled(bool enabled);
  Future<bool> hasLocalJmSourceFile();
  Future<bool> hasLocalSourceFile(String sourceKey);
  Future<void> deleteLocalSourceFile(String sourceKey);
  Future<void> downloadSourceFile(
    String sourceKey, {
    void Function(int received, int total)? onProgress,
  });
  Future<String?> readLocalActiveSourceIfExists();
  Future<void> writeLocalActiveSource(String content);
  Future<String> loadEditableActiveSource();
  Future<void> saveEditedActiveSource(String content);
  Future<bool> hasCustomEditedActiveSource();
  Future<bool> hasCustomEditedSource(String sourceKey);
  Future<void> reloadFromLocalSourceFiles();
  Future<SourceVersionCheckResult?> checkActiveSourceVersionFromCloud();
  Future<bool> downloadActiveSourceAndReload({
    void Function(int received, int total)? onProgress,
  });
  Future<bool> refreshSourceOnNetworkRecovery();
}

class SourceRuntimeOperationService implements SourceRuntimeOperations {
  const SourceRuntimeOperationService(
    this._initialization,
    this._diagnostics,
    this._scripts,
    this._updates,
    this._recovery,
  );

  final SourceRuntimeInitializationOperations _initialization;
  final SourceRuntimeDiagnosticsOperations _diagnostics;
  final SourceScriptEditingOperations _scripts;
  final SourceUpdateOperations _updates;
  final SourceRuntimeRecoveryOperations _recovery;

  Future<void> init({
    void Function(int received, int total)? onSourceDownloadProgress,
    bool prewarm = false,
  }) => _initialization.init(
    onSourceDownloadProgress: onSourceDownloadProgress,
    prewarm: prewarm,
  );

  Future<void> ensureInitialized({String? sourceKey}) =>
      _initialization.ensureInitialized(sourceKey: sourceKey);
  Future<void> ensureSourceInitialized(String sourceKey) =>
      _initialization.ensureSourceInitialized(sourceKey);
  Future<void> prewarmInBackground() => _initialization.prewarmInBackground();
  void logRuntimeRetryRequested(String source) =>
      _diagnostics.logRuntimeRetryRequested(source);
  Future<bool> loadSoftwareLogCaptureEnabled() =>
      _diagnostics.loadSoftwareLogCaptureEnabled();
  Future<void> setSoftwareLogCaptureEnabled(bool enabled) =>
      _diagnostics.setSoftwareLogCaptureEnabled(enabled);
  Future<bool> hasLocalJmSourceFile() => _scripts.hasLocalActiveSourceFile();
  Future<bool> hasLocalSourceFile(String sourceKey) =>
      _scripts.hasLocalSourceFile(sourceKey);
  Future<void> deleteLocalSourceFile(String sourceKey) =>
      _scripts.deleteLocalSourceFile(sourceKey);
  Future<void> downloadSourceFile(
    String sourceKey, {
    void Function(int received, int total)? onProgress,
  }) => _recovery.downloadSourceFile(sourceKey, onProgress: onProgress);
  Future<String?> readLocalActiveSourceIfExists() =>
      _scripts.readLocalActiveSourceIfExists();
  Future<void> writeLocalActiveSource(String content) =>
      _scripts.writeLocalActiveSource(content);
  Future<String> loadEditableActiveSource() =>
      _scripts.loadEditableActiveSource();
  Future<void> saveEditedActiveSource(String content) =>
      _scripts.saveEditedActiveSource(content);
  Future<bool> hasCustomEditedActiveSource() =>
      _scripts.hasCustomEditedActiveSource();
  Future<bool> hasCustomEditedSource(String sourceKey) =>
      _scripts.hasCustomEditedSource(sourceKey);
  Future<void> reloadFromLocalSourceFiles() =>
      _recovery.reloadFromLocalSourceFiles();
  Future<SourceVersionCheckResult?> checkActiveSourceVersionFromCloud() =>
      _updates.checkActiveSourceVersion();
  Future<bool> downloadActiveSourceAndReload({
    void Function(int received, int total)? onProgress,
  }) => _updates.downloadActiveSource(onProgress: onProgress);
  Future<bool> refreshSourceOnNetworkRecovery() =>
      _recovery.refreshSourceOnNetworkRecovery();
}
