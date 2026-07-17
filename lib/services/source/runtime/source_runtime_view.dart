import 'package:flutter/foundation.dart';

import '../../../models/hazuki_models.dart';
import '../models/source_contract_models.dart';
import '../models/source_identity.dart';
import 'source_runtime_host.dart';
import 'source_runtime_operations.dart';
import 'source_runtime_registry.dart';

abstract interface class SourceRuntimeView implements Listenable {
  SourceRuntimeRegistry get runtimeRegistry;
  String get activeSourceKey;
  bool get isActiveJmSource;
  bool get isActiveCopyMangaSource;
  bool get isActiveDailyCheckInSource;
  bool get isInitialized;
  SourceMeta? get sourceMeta;
  SourceRuntimeState get sourceRuntimeState;
  SourceRuntimeState get runtimeState;

  Future<void> loadActiveSourcePreference();
  Future<void> activateSource(String sourceKey);
  Future<void> prewarmInBackground();
  void logRuntimeRetryRequested(String source);
}

class SourceRuntimeViewService implements SourceRuntimeView {
  SourceRuntimeViewService({
    required SourceRuntimeHost runtimeHost,
    required SourceRuntimeOperations runtimeOperations,
  }) : _runtimeHost = runtimeHost,
       _runtimeOperations = runtimeOperations;

  final SourceRuntimeHost _runtimeHost;
  final SourceRuntimeOperations _runtimeOperations;

  @override
  SourceRuntimeRegistry get runtimeRegistry => _runtimeHost.runtimeRegistry;
  @override
  String get activeSourceKey => _runtimeHost.activeSourceKey;
  @override
  bool get isActiveJmSource => isHazukiJmSourceKey(activeSourceKey);
  @override
  bool get isActiveCopyMangaSource =>
      isHazukiCopyMangaSourceKey(activeSourceKey);
  @override
  bool get isActiveDailyCheckInSource =>
      isHazukiJmSourceKey(activeSourceKey) ||
      isHazukiPicacgSourceKey(activeSourceKey);
  @override
  bool get isInitialized {
    final runtime = _runtimeHost.activeHandle.runtime;
    return runtime.engine != null && runtime.sourceMeta != null;
  }

  @override
  SourceMeta? get sourceMeta => _runtimeHost.activeHandle.runtime.sourceMeta;
  @override
  SourceRuntimeState get sourceRuntimeState =>
      _runtimeHost.activeHandle.runtime.runtimeState;
  @override
  SourceRuntimeState get runtimeState =>
      _runtimeHost.activeHandle.facade.runtimeState;

  @override
  Future<void> loadActiveSourcePreference() =>
      _runtimeHost.loadActiveSourcePreference();
  @override
  Future<void> activateSource(String sourceKey) =>
      _runtimeHost.activateSource(sourceKey);
  @override
  Future<void> prewarmInBackground() =>
      _runtimeOperations.prewarmInBackground();
  @override
  void logRuntimeRetryRequested(String source) =>
      _runtimeOperations.logRuntimeRetryRequested(source);
  @override
  void addListener(VoidCallback listener) => _runtimeHost.addListener(listener);
  @override
  void removeListener(VoidCallback listener) =>
      _runtimeHost.removeListener(listener);
}
