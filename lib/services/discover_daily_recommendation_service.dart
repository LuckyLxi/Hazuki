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
           const SharedPreferencesDiscoverDailyRecommendationCacheStore() {
    _candidateGenerator =
        candidateGenerator ??
        SourceDiscoverDailyRecommendationCandidateGenerator(
          source: source,
          random: math.Random(),
          now: _now,
        );
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

  DiscoverDailyRecommendationState get state => _state;

  bool get _supportsActiveSource => _source.isActiveJmSource;

  Future<void> setEnabled(bool enabled) async {
    await _cacheStore.setEnabled(enabled);
    if (!enabled) {
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
      _setState(const DiscoverDailyRecommendationState.disabled());
      return _state;
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

    final cached = await _cacheStore.readSnapshot(
      activeSourceKey: _source.activeSourceKey,
    );
    if (cached != null) {
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
    if (generated == null) {
      _setState(const DiscoverDailyRecommendationState(enabled: true));
      return _state;
    }

    await _cacheStore.persistSnapshot(generated);
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

    final completer = Completer<void>();
    _refreshInFlight = completer.future;
    _setState(_state.copyWith(isRefreshing: true));

    try {
      final generated = await _generateRecommendations();
      if (generated == null || !_state.enabled || !_supportsActiveSource) {
        return;
      }

      final preloaded = await _preloadRecommendationImages(
        generated.recommendations,
      );
      if (!preloaded || !_state.enabled || !_supportsActiveSource) {
        return;
      }

      await _cacheStore.persistSnapshot(generated);
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
      _refreshInFlight = null;
      if (!_state.isPendingReady) {
        _setState(_state.copyWith(isRefreshing: false));
      }
      if (!completer.isCompleted) {
        completer.complete();
      }
    }
  }

  Future<bool> _preloadRecommendationImages(
    List<DiscoverDailyRecommendationEntry> recommendations,
  ) async {
    final imageUrls = recommendations
        .map((entry) => entry.comic.cover.trim())
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
    final previous =
        _state.displayedRecommendations.length == recommendationCount
        ? _state.displayedRecommendations
        : const <DiscoverDailyRecommendationEntry>[];
    return _candidateGenerator.generate(previous: previous);
  }

  void _handleSourceChanged() {
    if (!_supportsActiveSource) {
      _setState(const DiscoverDailyRecommendationState.disabled());
      return;
    }
    unawaited(_restoreForActiveSource());
  }

  Future<void> _restoreForActiveSource() async {
    final enabled = await loadEnabled();
    await ensurePrepared(enabled: enabled);
  }

  @override
  void dispose() {
    _source.removeListener(_handleSourceChanged);
    super.dispose();
  }
}
