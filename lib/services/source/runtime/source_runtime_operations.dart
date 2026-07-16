// The implementation below intentionally mirrors the complete interface.
// ignore_for_file: annotate_overrides

import '../models/source_contract_models.dart';
import 'source_runtime_capability.dart';

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
  const SourceRuntimeOperationService(this._runtime);

  final SourceRuntimeCapability _runtime;

  Future<void> init({
    void Function(int received, int total)? onSourceDownloadProgress,
    bool prewarm = false,
  }) => _runtime.init(
    onSourceDownloadProgress: onSourceDownloadProgress,
    prewarm: prewarm,
  );

  Future<void> ensureInitialized({String? sourceKey}) =>
      _runtime.ensureInitialized(sourceKey: sourceKey);
  Future<void> ensureSourceInitialized(String sourceKey) =>
      _runtime.ensureSourceInitialized(sourceKey);
  Future<void> prewarmInBackground() => _runtime.prewarmInBackground();
  void logRuntimeRetryRequested(String source) =>
      _runtime.logRuntimeRetryRequested(source);
  Future<bool> loadSoftwareLogCaptureEnabled() =>
      _runtime.loadSoftwareLogCaptureEnabled();
  Future<void> setSoftwareLogCaptureEnabled(bool enabled) =>
      _runtime.setSoftwareLogCaptureEnabled(enabled);
  Future<bool> hasLocalJmSourceFile() => _runtime.hasLocalJmSourceFile();
  Future<bool> hasLocalSourceFile(String sourceKey) =>
      _runtime.hasLocalSourceFile(sourceKey);
  Future<void> deleteLocalSourceFile(String sourceKey) =>
      _runtime.deleteLocalSourceFile(sourceKey);
  Future<void> downloadSourceFile(
    String sourceKey, {
    void Function(int received, int total)? onProgress,
  }) => _runtime.downloadSourceFile(sourceKey, onProgress: onProgress);
  Future<String?> readLocalActiveSourceIfExists() =>
      _runtime.readLocalActiveSourceIfExists();
  Future<void> writeLocalActiveSource(String content) =>
      _runtime.writeLocalActiveSource(content);
  Future<String> loadEditableActiveSource() =>
      _runtime.loadEditableActiveSource();
  Future<void> saveEditedActiveSource(String content) =>
      _runtime.saveEditedActiveSource(content);
  Future<bool> hasCustomEditedActiveSource() =>
      _runtime.hasCustomEditedActiveSource();
  Future<bool> hasCustomEditedSource(String sourceKey) =>
      _runtime.hasCustomEditedSource(sourceKey);
  Future<void> reloadFromLocalSourceFiles() =>
      _runtime.reloadFromLocalSourceFiles();
  Future<SourceVersionCheckResult?> checkActiveSourceVersionFromCloud() =>
      _runtime.checkActiveSourceVersionFromCloud();
  Future<bool> downloadActiveSourceAndReload({
    void Function(int received, int total)? onProgress,
  }) => _runtime.downloadActiveSourceAndReload(onProgress: onProgress);
  Future<bool> refreshSourceOnNetworkRecovery() =>
      _runtime.refreshSourceOnNetworkRecovery();
}
