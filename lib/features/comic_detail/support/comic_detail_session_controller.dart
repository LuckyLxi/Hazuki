import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:hazuki/models/hazuki_models.dart';

import '../repository/comic_detail_repository.dart';
import 'package:hazuki/shared/ui_flags.dart';

class ComicDetailSessionController extends ChangeNotifier {
  ComicDetailSessionController({
    required ComicDetailFeatureFacade repository,
    required ExploreComic comic,
    required String sourceKey,
    required void Function({
      required bool favoriteOverride,
      required bool cloudFavoriteOverride,
    })
    applyInitialFavoriteOverrides,
  }) : _repository = repository,
       _comic = comic,
       _sourceKey = sourceKey,
       _applyInitialFavoriteOverrides = applyInitialFavoriteOverrides;

  final ComicDetailFeatureFacade _repository;
  final ExploreComic _comic;
  final String _sourceKey;
  final void Function({
    required bool favoriteOverride,
    required bool cloudFavoriteOverride,
  })
  _applyInitialFavoriteOverrides;

  bool _disposed = false;

  late Future<ComicDetailsData> _future;
  Timer? _detailsTimeoutTimer;
  bool _hasDetailsTimedOut = false;
  bool _isRetryingDetails = false;
  bool _hasAutomaticallyRetriedDetails = false;
  int _detailsRequestId = 0;
  Map<String, dynamic>? _lastReadProgress;

  Future<ComicDetailsData> get future => _future;
  bool get hasDetailsTimedOut => _hasDetailsTimedOut;
  bool get isRetryingDetails => _isRetryingDetails;
  Map<String, dynamic>? get lastReadProgress => _lastReadProgress;

  void initialize() {
    _future = _createComicDetailsFuture();
    unawaited(_warmupReaderImages());
    unawaited(loadReadingProgress());
    unawaited(_loadFavoriteOverrideState());
    unawaited(_recordHistory());
  }

  void retry() {
    if (_disposed) return;
    _startDetailRetry();
  }

  void _startDetailRetry() {
    _detailsTimeoutTimer?.cancel();
    _detailsTimeoutTimer = null;
    _hasDetailsTimedOut = false;
    _isRetryingDetails = true;
    _future = _createComicDetailsFuture(forceRefresh: true);
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _detailsTimeoutTimer?.cancel();
    _detailsTimeoutTimer = null;
    super.dispose();
  }

  Future<void> loadReadingProgress() async {
    try {
      final progress = await _repository.loadReadingProgress(_comic.id);
      if (progress == null || _disposed) return;
      _lastReadProgress = progress;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _loadFavoriteOverrideState() async {
    try {
      final details = await _future;
      final localFavorite = await _repository.isComicLocallyFavorited(
        details.id.trim().isNotEmpty ? details.id : _comic.id,
        sourceKey: details.sourceKey,
      );
      if (_disposed) return;
      _applyInitialFavoriteOverrides(
        favoriteOverride: details.isFavorite || localFavorite,
        cloudFavoriteOverride: details.isFavorite,
      );
    } catch (_) {}
  }

  Future<void> _recordHistory() async {
    try {
      final details = await _future;
      if (_disposed) return;
      await _repository.recordHistory(comic: _comic, details: details);
    } catch (_) {}
  }

  Future<void> _warmupReaderImages() async {
    if (hazukiNoImageModeNotifier.value) return;
    try {
      final details = await _future;
      if (_disposed || details.chapters.isEmpty) return;
      final first = details.chapters.entries.first;
      final images = await _repository.loadChapterImages(
        comicId: details.id,
        epId: first.key,
        sourceKey: details.sourceKey,
      );
      if (_disposed) return;
      await _repository.prefetchComicImages(
        comicId: details.id,
        epId: first.key,
        imageUrls: images,
        count: 3,
        memoryCount: 1,
        sourceKey: details.sourceKey,
      );
    } catch (_) {}
  }

  Future<ComicDetailsData> _createComicDetailsFuture({
    bool forceRefresh = false,
  }) {
    final requestId = ++_detailsRequestId;
    final sourceFuture = _repository.loadComicDetails(
      _comic.id,
      sourceKey: _sourceKey,
      forceRefresh: forceRefresh,
    );

    late final Timer timeoutTimer;
    timeoutTimer = Timer(const Duration(seconds: 30), () {
      if (_disposed || requestId != _detailsRequestId) return;
      if (!_hasAutomaticallyRetriedDetails) {
        _hasAutomaticallyRetriedDetails = true;
        _startDetailRetry();
        return;
      }
      _hasDetailsTimedOut = true;
      notifyListeners();
    });
    _detailsTimeoutTimer = timeoutTimer;

    sourceFuture.then(
      (_) => _onDetailsFutureFinished(requestId, timeoutTimer),
      onError: (Object error, StackTrace _) {
        if (_shouldAutomaticallyRetryAfterHttp210(error)) {
          _hasAutomaticallyRetriedDetails = true;
          _startDetailRetry();
          return;
        }
        _onDetailsFutureFinished(requestId, timeoutTimer);
      },
    );

    return sourceFuture;
  }

  void _onDetailsFutureFinished(int requestId, Timer timeoutTimer) {
    timeoutTimer.cancel();
    if (identical(_detailsTimeoutTimer, timeoutTimer)) {
      _detailsTimeoutTimer = null;
    }
    if (_disposed || requestId != _detailsRequestId) return;
    final shouldNotify = _hasDetailsTimedOut || _isRetryingDetails;
    _hasDetailsTimedOut = false;
    _isRetryingDetails = false;
    if (shouldNotify) notifyListeners();
  }

  bool _shouldAutomaticallyRetryAfterHttp210(Object error) {
    if (_disposed ||
        _hasAutomaticallyRetriedDetails ||
        _sourceKey.trim() != 'copy_manga') {
      return false;
    }
    return error.toString().contains(
      'copy_manga_runtime_recovery_failed_after_http_210',
    );
  }
}
