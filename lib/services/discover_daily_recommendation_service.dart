import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'source/source_capabilities.dart';
import 'discover_daily_recommendation/discover_recommendation_models.dart';
import 'discover_daily_recommendation/discover_recommendation_config.dart';
import 'discover_daily_recommendation/discover_recommendation_cache_store.dart';
import 'discover_daily_recommendation/discover_recommendation_generator.dart';

export 'discover_daily_recommendation/discover_recommendation_models.dart';
export 'discover_daily_recommendation/discover_recommendation_cache_store.dart';
export 'discover_daily_recommendation/discover_recommendation_generator.dart';
export 'discover_daily_recommendation/discover_recommendation_policy.dart';

class DiscoverDailyRecommendationService extends ChangeNotifier {
  DiscoverDailyRecommendationService({
    required SourceDailyRecommendationGateway source,
    DiscoverDailyRecommendationCacheStore? cacheStore,
    DiscoverDailyRecommendationCandidateGenerator? candidateGenerator,
    DateTime Function()? now,
  }) : _source = source,
       _now = now ?? DateTime.now,
       _cacheStore =
           cacheStore ??
           SharedPreferencesDiscoverDailyRecommendationCacheStore() {
    _candidateGenerator =
        candidateGenerator ??
        SourceDiscoverDailyRecommendationCandidateGenerator(
          source: source,
          random: math.Random(),
          now: _now,
        );
    _stateSourceKey = (_source.activeSourceKey ?? '').trim();
    _stateConfigurationKey = _source
        .dailyRecommendationForSource(_stateSourceKey)
        ?.cacheKey;
    _source.addListener(_handleSourceChanged);
  }

  final SourceDailyRecommendationGateway _source;
  final DiscoverDailyRecommendationCacheStore _cacheStore;
  late final DiscoverDailyRecommendationCandidateGenerator _candidateGenerator;

  static const String authorsAssetPath =
      DiscoverDailyRecommendationConfig.authorsAssetPath;
  static const int recommendationCount =
      DiscoverDailyRecommendationConfig.recommendationCount;
  static const int maxAuthorSearchAttempts =
      DiscoverDailyRecommendationConfig.maxAuthorSearchAttempts;
  static const int maxConsecutiveSearchFailures =
      DiscoverDailyRecommendationConfig.maxConsecutiveSearchFailures;

  final DateTime Function() _now;

  DiscoverDailyRecommendationState _state =
      const DiscoverDailyRecommendationState.disabled();
  Future<void>? _refreshInFlight;
  int _generation = 0;
  bool _disposed = false;
  late String _stateSourceKey;
  String? _stateConfigurationKey;

  bool _isCurrent(int generation, String sourceKey) =>
      !_disposed &&
      generation == _generation &&
      _supportsActiveSource &&
      (_source.activeSourceKey ?? '').trim() == sourceKey;

  DiscoverDailyRecommendationState get state => _state;

  bool get _supportsActiveSource => _source.supportsDailyRecommendation;

  bool get usesPluginRecommendations =>
      _source.dailyRecommendationForSource(_stateSourceKey)?.mode ==
      DailyRecommendationMode.plugin;

  Future<void> setEnabled(bool enabled) async {
    await _cacheStore.setEnabled(enabled);
    if (!enabled) {
      _generation++;
      _setState(const DiscoverDailyRecommendationState.disabled());
      return;
    }
    if (!_supportsActiveSource) {
      _setState(const DiscoverDailyRecommendationState.disabled());
      return;
    }
    _setState(_state.copyWith(enabled: true));
  }

  Future<bool> loadEnabled() async {
    return _cacheStore.loadEnabled();
  }

  Future<DiscoverDailyRecommendationState> ensurePrepared({
    required bool enabled,
  }) async {
    if (!enabled || !_supportsActiveSource) {
      _generation++;
      _setState(const DiscoverDailyRecommendationState.disabled());
      return _state;
    }

    final generation = _generation;
    final sourceKey = (_source.activeSourceKey ?? '').trim();
    if (_stateSourceKey != sourceKey) {
      _stateSourceKey = sourceKey;
      _setState(const DiscoverDailyRecommendationState.disabled());
    }

    if (_state.isPendingReady && _state.hasPendingRecommendations) {
      _setState(_state.copyWith(enabled: true, isRefreshing: false));
      return _state;
    }

    if (_state.hasRecommendations) {
      _setState(_state.copyWith(enabled: true));
      if (!_isDisplayedFresh(_state)) {
        unawaited(_refreshPendingRecommendations());
      }
      return _state;
    }

    final cached = await _cacheStore.readSnapshot(activeSourceKey: sourceKey);
    if (!_isCurrent(generation, sourceKey)) return _state;
    if (cached != null &&
        cached.sourceKey.trim() == sourceKey &&
        _matchesConfiguration(cached, sourceKey) &&
        cached.recommendations.every(
          (entry) => entry.comic.sourceKey.trim() == sourceKey,
        )) {
      _setState(_snapshotToDisplayedState(cached));
      if (!_isCacheFresh(cached)) {
        unawaited(_refreshPendingRecommendations());
      }
      return _state;
    }

    if (!_source.isInitialized) {
      _setState(const DiscoverDailyRecommendationState(enabled: true));
      return _state;
    }

    final generated = await _generateRecommendations();
    if (!_isCurrent(generation, sourceKey)) return _state;
    if (generated == null) {
      _setState(const DiscoverDailyRecommendationState(enabled: true));
      return _state;
    }

    await _cacheStore.persistSnapshot(generated);
    if (!_isCurrent(generation, sourceKey)) return _state;
    _setState(_snapshotToDisplayedState(generated));
    return _state;
  }

  Future<void> promotePendingRecommendations() async {
    if (!_state.isPendingReady || !_state.hasPendingRecommendations) {
      return;
    }
    _setState(
      DiscoverDailyRecommendationState(
        enabled: _state.enabled,
        displayedRecommendations: _state.pendingRecommendations,
        selectedAuthor: _state.pendingSelectedAuthor,
        generatedAt: _state.pendingGeneratedAt,
        isRefreshing: false,
        isPendingReady: false,
      ),
    );
  }

  void _setState(DiscoverDailyRecommendationState next) {
    _state = DiscoverDailyRecommendationState(
      enabled: next.enabled,
      displayedRecommendations:
          List<DiscoverDailyRecommendationEntry>.unmodifiable(
            next.displayedRecommendations,
          ),
      pendingRecommendations:
          List<DiscoverDailyRecommendationEntry>.unmodifiable(
            next.pendingRecommendations,
          ),
      selectedAuthor: next.selectedAuthor,
      generatedAt: next.generatedAt,
      pendingSelectedAuthor: next.pendingSelectedAuthor,
      pendingGeneratedAt: next.pendingGeneratedAt,
      isRefreshing: next.isRefreshing,
      isPendingReady: next.isPendingReady,
    );
    notifyListeners();
  }

  DiscoverDailyRecommendationState _snapshotToDisplayedState(
    DiscoverDailyRecommendationSnapshot snapshot,
  ) {
    return DiscoverDailyRecommendationState(
      enabled: true,
      displayedRecommendations: snapshot.recommendations,
      selectedAuthor: snapshot.selectedAuthor,
      generatedAt: snapshot.generatedAt,
      isRefreshing: false,
      isPendingReady: false,
    );
  }

  Future<void> _refreshPendingRecommendations() async {
    if (_refreshInFlight != null ||
        !_state.enabled ||
        _state.isPendingReady ||
        !_supportsActiveSource ||
        !_source.isInitialized) {
      return;
    }

    final generation = _generation;
    final sourceKey = (_source.activeSourceKey ?? '').trim();
    final completer = Completer<void>();
    _refreshInFlight = completer.future;
    _setState(_state.copyWith(isRefreshing: true));

    try {
      final generated = await _generateRecommendations();
      if (generated == null ||
          !_state.enabled ||
          !_isCurrent(generation, sourceKey)) {
        return;
      }

      if (usesPluginRecommendations) {
        // Publish the entries before downloading images so each visible card
        // can show its placeholder and reveal independently when ready.
        await _cacheStore.persistSnapshot(generated);
        if (_state.enabled && _isCurrent(generation, sourceKey)) {
          _setState(_snapshotToDisplayedState(generated));
        }
        return;
      }

      final preloaded = await _preloadRecommendationImages(
        generated.recommendations,
        sourceKey: sourceKey,
      );
      if (!preloaded || !_state.enabled || !_isCurrent(generation, sourceKey)) {
        return;
      }

      await _cacheStore.persistSnapshot(generated);
      if (!_isCurrent(generation, sourceKey)) return;
      if (generated.recommendations.isEmpty) {
        _setState(_snapshotToDisplayedState(generated));
        return;
      }
      _setState(
        _state.copyWith(
          pendingRecommendations: generated.recommendations,
          pendingSelectedAuthor: generated.selectedAuthor,
          pendingGeneratedAt: generated.generatedAt,
          isRefreshing: false,
          isPendingReady: true,
        ),
      );
    } finally {
      if (identical(_refreshInFlight, completer.future)) {
        _refreshInFlight = null;
      }
      if (_isCurrent(generation, sourceKey) && !_state.isPendingReady) {
        _setState(_state.copyWith(isRefreshing: false));
      }
      if (!completer.isCompleted) {
        completer.complete();
      }
    }
  }

  Future<bool> _preloadRecommendationImages(
    List<DiscoverDailyRecommendationEntry> recommendations, {
    required String sourceKey,
  }) async {
    final imageUrls = recommendations
        .map((entry) => entry.displayImageUrl.trim())
        .where((url) => url.isNotEmpty)
        .toList(growable: false);
    if (imageUrls.length != recommendations.length) {
      return false;
    }
    try {
      await Future.wait(
        imageUrls.map((url) async {
          final bytes = await _source.downloadImageBytes(
            url,
            keepInMemory: true,
            sourceKey: sourceKey,
          );
          if (bytes.isEmpty) {
            throw Exception('recommendation_cover_empty');
          }
        }),
        eagerError: true,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  bool _isDisplayedFresh(DiscoverDailyRecommendationState state) {
    final generatedAt = state.generatedAt;
    if (generatedAt == null) {
      return false;
    }
    return _now().difference(generatedAt) <=
        DiscoverDailyRecommendationConfig.cacheTtl;
  }

  bool _isCacheFresh(DiscoverDailyRecommendationSnapshot snapshot) {
    return snapshot.schemaVersion ==
            DiscoverDailyRecommendationConfig.cacheSchemaVersion &&
        _now().difference(snapshot.generatedAt) <=
            DiscoverDailyRecommendationConfig.cacheTtl;
  }

  Future<DiscoverDailyRecommendationSnapshot?>
  _generateRecommendations() async {
    return _candidateGenerator.generate(
      previous: _state.displayedRecommendations,
    );
  }

  bool _matchesConfiguration(
    DiscoverDailyRecommendationSnapshot snapshot,
    String sourceKey,
  ) {
    final config = _source.dailyRecommendationForSource(sourceKey);
    if (config == null) return false;
    return snapshot.configurationKey.isEmpty
        ? config.mode == DailyRecommendationMode.authors
        : snapshot.configurationKey == config.cacheKey;
  }

  void _handleSourceChanged() {
    final sourceKey = (_source.activeSourceKey ?? '').trim();
    final configurationKey = _source
        .dailyRecommendationForSource(sourceKey)
        ?.cacheKey;
    if (sourceKey != _stateSourceKey ||
        configurationKey != _stateConfigurationKey) {
      _generation++;
      _stateSourceKey = sourceKey;
      _stateConfigurationKey = configurationKey;
      _refreshInFlight = null;
      _setState(const DiscoverDailyRecommendationState.disabled());
    }
    if (!_supportsActiveSource) {
      _setState(const DiscoverDailyRecommendationState.disabled());
      return;
    }
    unawaited(_restoreForActiveSource());
  }

  Future<void> _restoreForActiveSource() async {
    final generation = _generation;
    final sourceKey = (_source.activeSourceKey ?? '').trim();
    final enabled = await loadEnabled();
    if (!_isCurrent(generation, sourceKey)) return;
    await ensurePrepared(enabled: enabled);
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _source.removeListener(_handleSourceChanged);
    super.dispose();
  }
}
