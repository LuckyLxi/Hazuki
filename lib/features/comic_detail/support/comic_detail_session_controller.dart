import 'dart:async';
import 'package:hazuki/shared/source_task_owner.dart';
import 'package:hazuki/services/source/source_capabilities.dart';

import 'package:flutter/foundation.dart';

import 'package:hazuki/models/hazuki_models.dart';

import '../repository/comic_detail_repository.dart';
import 'package:hazuki/shared/ui_flags.dart';
import 'package:hazuki/services/source/interaction/source_ui_scope.dart';
import 'package:hazuki/services/source/interaction/source_ui_service.dart';

class ComicDetailSessionController extends ChangeNotifier {
  ComicDetailSessionController({
    SourceTaskControlGateway? taskControl,
    required ComicDetailFeatureFacade repository,
    required ExploreComic comic,
    required String sourceKey,
    required void Function({
      required bool favoriteOverride,
      required bool cloudFavoriteOverride,
    })
    applyInitialFavoriteOverrides,
  }) : _progressTasks = SourceTaskOwner(taskControl),
       _progressWatchTasks = SourceTaskOwner(taskControl),
       _repository = repository,
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
  final _sourceUi = SourceUiOwner();
  final SourceTaskOwner _progressTasks;
  final SourceTaskOwner _progressWatchTasks;

  late Future<ComicDetailsData> _future;
  Timer? _detailsTimeoutTimer;
  bool _hasDetailsTimedOut = false;
  bool _isRetryingDetails = false;
  bool _hasAutomaticallyRetriedDetails = false;
  int _detailsRequestId = 0;
  Map<String, dynamic>? _lastReadProgress;
  int _readingRequestId = 0;
  StreamSubscription<void>? _readingProgressSubscription;

  Future<ComicDetailsData> get future => _future;
  bool get hasDetailsTimedOut => _hasDetailsTimedOut;
  bool get isRetryingDetails => _isRetryingDetails;
  Map<String, dynamic>? get lastReadProgress => _lastReadProgress;

  void initialize() {
    _future = _createComicDetailsFuture();
    unawaited(_sourceUi.runBackground(_warmupReaderImages));
    // Route return can precede the reader's asynchronous exit save.
    _readingProgressSubscription = _repository
        .watchReadingProgressChanges(taskOrigin: _progressWatchTasks.origin())
        .listen(
          (_) => unawaited(loadReadingProgress()),
          onError: (Object _) {},
        );
    unawaited(loadReadingProgress());
    unawaited(_loadFavoriteOverrideState());
    unawaited(_recordHistory());
  }

  void retry() {
    if (_disposed) return;
    _startDetailRetry();
  }

  /// 插件动作要求刷新时静默重载：新数据到达前继续显示旧详情，
  /// 失败时保留旧详情而不进入错误页；返回的 Future 仍会抛出失败。
  Future<void> reloadDetails() async {
    if (_disposed) return;
    final previous = _future;
    final fresh = _createComicDetailsFuture(forceRefresh: true);
    _future = fresh.catchError((Object _) => previous);
    notifyListeners();
    await fresh;
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
    _progressTasks.dispose();
    _progressWatchTasks.dispose();
    _sourceUi.dispose();
    unawaited(_readingProgressSubscription?.cancel());
    _detailsTimeoutTimer?.cancel();
    _detailsTimeoutTimer = null;
    super.dispose();
  }

  Future<void> loadReadingProgress() async {
    if (_disposed) return;
    final request = ++_readingRequestId;
    _lastReadProgress = null;
    _progressTasks.restart();
    final origin = _progressTasks.origin();
    try {
      final progress = await _repository.loadReadingProgress(
        _comic.id,
        taskOrigin: origin,
      );
      if (_disposed || request != _readingRequestId) return;
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
    _sourceUi.restart();
    return _sourceUi.run(
      () => _createComicDetailsFutureWithUi(forceRefresh: forceRefresh),
    );
  }

  Future<ComicDetailsData> _createComicDetailsFutureWithUi({
    bool forceRefresh = false,
  }) {
    final requestId = ++_detailsRequestId;
    final sourceFuture = _repository.loadComicDetails(
      _comic.id,
      sourceKey: _sourceKey,
      forceRefresh: forceRefresh,
    );

    late final Timer timeoutTimer;
    timeoutTimer = SourceUiScope.timer(const Duration(seconds: 30), () {
      if (_disposed || requestId != _detailsRequestId) return;
      if (!_hasAutomaticallyRetriedDetails && !_sourceUi.wasCancelled) {
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
}
