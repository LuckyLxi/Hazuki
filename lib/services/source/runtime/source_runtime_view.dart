import '../plugins/source_search_capabilities.dart';
import 'package:flutter/foundation.dart';

import '../../../models/hazuki_models.dart';
import '../models/source_contract_models.dart';
import 'source_runtime_host.dart';
import 'source_runtime_operations.dart';
import 'source_runtime_registry.dart';

abstract interface class SourceRuntimeView implements Listenable {
  SourceRuntimeRegistry get runtimeRegistry;
  String? get activeSourceKey;
  String? get sourceRevision;
  bool get supportsDirectComicId;
  bool get supportsDailyRecommendation;
  DirectComicIdRules? directComicIdRulesForSource(String sourceKey);
  DailyRecommendationConfig? dailyRecommendationForSource(String sourceKey);
  bool get supportsLegacyRanking;
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
  String? get activeSourceKey =>
      _runtimeHost.hasActiveSource ? _runtimeHost.activeSourceKey : null;
  @override
  String? get sourceRevision {
    final id = activeSourceKey;
    if (id == null) return null;
    final entry = runtimeRegistry.definitionFor(id);
    return '$id|${entry.pluginVersion}|${entry.pluginDirectory}';
  }

  @override
  bool get supportsDirectComicId =>
      directComicIdRulesForSource(activeSourceKey ?? '') != null;
  @override
  bool get supportsDailyRecommendation =>
      dailyRecommendationForSource(activeSourceKey ?? '') != null;
  Map<String, dynamic> _presentationFor(String sourceKey) {
    return runtimeRegistry.presentationFor(sourceKey);
  }

  @override
  DirectComicIdRules? directComicIdRulesForSource(String sourceKey) =>
      DirectComicIdRules.parse(
        _presentationFor(sourceKey)['directComicIdRules'],
      );
  @override
  DailyRecommendationConfig? dailyRecommendationForSource(String sourceKey) =>
      DailyRecommendationConfig.parse(
        _presentationFor(sourceKey)['dailyRecommendation'],
      );
  @override
  bool get supportsLegacyRanking => _runtimeHost.feature('legacyRanking');
  @override
  bool get isActiveDailyCheckInSource => _runtimeHost.supportsDailyCheckIn;
  @override
  bool get isInitialized {
    final runtime = _runtimeHost.optionalActiveHandle?.runtime;
    if (runtime == null) return false;
    return runtime.engine != null && runtime.sourceMeta != null;
  }

  @override
  SourceMeta? get sourceMeta =>
      _runtimeHost.optionalActiveHandle?.runtime.sourceMeta;
  @override
  SourceRuntimeState get sourceRuntimeState =>
      _runtimeHost.optionalActiveHandle?.runtime.runtimeState ??
      const SourceRuntimeState.idle();
  @override
  SourceRuntimeState get runtimeState => sourceRuntimeState;

  @override
  Future<void> loadActiveSourcePreference() =>
      runtimeRegistry.loadActiveSourcePreference();
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
