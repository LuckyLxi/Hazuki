import '../plugins/source_search_capabilities.dart';
import 'package:flutter/foundation.dart';

import '../../../models/hazuki_models.dart';
import '../models/source_contract_models.dart';
import 'source_runtime_host.dart';
import 'source_runtime_operations.dart';
import 'source_runtime_registry.dart';

class SourceRuntimeView implements Listenable {
  SourceRuntimeView({
    required SourceRuntimeHost runtimeHost,
    required SourceRuntimeOperations runtimeOperations,
  }) : _runtimeHost = runtimeHost,
       _runtimeOperations = runtimeOperations;

  final SourceRuntimeHost _runtimeHost;
  final SourceRuntimeOperations _runtimeOperations;

  SourceRuntimeRegistry get runtimeRegistry => _runtimeHost.runtimeRegistry;
  String? get activeSourceKey =>
      _runtimeHost.hasActiveSource ? _runtimeHost.activeSourceKey : null;
  String? get sourceRevision {
    final id = activeSourceKey;
    if (id == null) return null;
    final entry = runtimeRegistry.definitionFor(id);
    return '$id|${entry.pluginVersion}|${entry.pluginDirectory}';
  }

  bool get supportsDirectComicId =>
      directComicIdRulesForSource(activeSourceKey ?? '') != null;
  bool get supportsDailyRecommendation =>
      dailyRecommendationForSource(activeSourceKey ?? '') != null;
  Map<String, dynamic> _presentationFor(String sourceKey) {
    return runtimeRegistry.presentationFor(sourceKey);
  }

  DirectComicIdRules? directComicIdRulesForSource(String sourceKey) =>
      DirectComicIdRules.parse(
        _presentationFor(sourceKey)['directComicIdRules'],
      );
  DailyRecommendationConfig? dailyRecommendationForSource(String sourceKey) =>
      DailyRecommendationConfig.parse(
        _presentationFor(sourceKey)['dailyRecommendation'],
      );
  bool get supportsLegacyRanking => _runtimeHost.feature('legacyRanking');
  bool get isActiveDailyCheckInSource => _runtimeHost.supportsDailyCheckIn;
  bool get isInitialized {
    final runtime = _runtimeHost.optionalActiveHandle?.runtime;
    if (runtime == null) return false;
    return runtime.engine != null && runtime.sourceMeta != null;
  }

  SourceMeta? get sourceMeta =>
      _runtimeHost.optionalActiveHandle?.runtime.sourceMeta;
  SourceRuntimeState get sourceRuntimeState =>
      _runtimeHost.optionalActiveHandle?.runtime.runtimeState ??
      const SourceRuntimeState.idle();
  SourceRuntimeState get runtimeState => sourceRuntimeState;

  Future<void> loadActiveSourcePreference() =>
      runtimeRegistry.loadActiveSourcePreference();
  Future<void> activateSource(String sourceKey) =>
      _runtimeHost.activateSource(sourceKey);
  Future<void> prewarmInBackground() =>
      _runtimeOperations.prewarmInBackground();
  void logRuntimeRetryRequested(String source) =>
      _runtimeOperations.logRuntimeRetryRequested(source);
  @override
  void addListener(VoidCallback listener) => _runtimeHost.addListener(listener);
  @override
  void removeListener(VoidCallback listener) =>
      _runtimeHost.removeListener(listener);
}
