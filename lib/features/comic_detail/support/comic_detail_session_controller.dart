import 'dart:async';

import 'package:flutter/material.dart';

import 'package:hazuki/app/app.dart';
import 'package:hazuki/models/hazuki_models.dart';

import '../repository/comic_detail_repository.dart';

final Set<String> _animatedComicDetailIds = <String>{};

class ComicDetailSessionController extends ChangeNotifier {
  ComicDetailSessionController({
    required ComicDetailRepository repository,
    required ExploreComic comic,
    required bool? shouldAnimateInitialRevealOverride,
    required TickerProvider vsync,
    required ScrollController scrollController,
    required void Function({
      required bool favoriteOverride,
      required bool cloudFavoriteOverride,
    })
    applyInitialFavoriteOverrides,
  }) : _repository = repository,
       _comic = comic,
       _shouldAnimateInitialRevealOverride = shouldAnimateInitialRevealOverride,
       _vsync = vsync,
       _scrollController = scrollController,
       _applyInitialFavoriteOverrides = applyInitialFavoriteOverrides;

  final ComicDetailRepository _repository;
  final ExploreComic _comic;
  final bool? _shouldAnimateInitialRevealOverride;
  final TickerProvider _vsync;
  final ScrollController _scrollController;
  final void Function({
    required bool favoriteOverride,
    required bool cloudFavoriteOverride,
  })
  _applyInitialFavoriteOverrides;

  bool _disposed = false;

  late final Future<ComicDetailsData> _future;
  late final ValueNotifier<double> _appBarSolidProgressNotifier;
  late final ValueNotifier<bool> _collapsedTitleNotifier;
  late final TabController _tabController;
  late final bool _shouldAnimateInitialDetailReveal;
  Timer? _detailsTimeoutTimer;
  String _appBarComicTitle = '';
  String _appBarUpdateTime = '';
  Map<String, dynamic>? _lastReadProgress;
  int _lastTabIndex = 0;
  bool _isAnimatingCommentsFullscreen = false;

  Future<ComicDetailsData> get future => _future;
  ValueNotifier<double> get appBarSolidProgressNotifier =>
      _appBarSolidProgressNotifier;
  ValueNotifier<bool> get collapsedTitleNotifier => _collapsedTitleNotifier;
  TabController get tabController => _tabController;
  bool get shouldAnimateInitialDetailReveal =>
      _shouldAnimateInitialDetailReveal;
  String get appBarComicTitle => _appBarComicTitle;
  String get appBarUpdateTime => _appBarUpdateTime;
  Map<String, dynamic>? get lastReadProgress => _lastReadProgress;

  void initialize() {
    _shouldAnimateInitialDetailReveal =
        _shouldAnimateInitialRevealOverride ??
        !_animatedComicDetailIds.contains(_comic.id.trim());
    _appBarSolidProgressNotifier = ValueNotifier<double>(0);
    _collapsedTitleNotifier = ValueNotifier<bool>(false);
    _tabController = TabController(length: 3, vsync: _vsync)
      ..addListener(_handleTabChanged);
    _appBarComicTitle = _comic.title;
    _future = _createComicDetailsFuture();
    _scrollController.addListener(_handleScroll);
    unawaited(_warmupReaderImages());
    unawaited(loadReadingProgress());
    unawaited(_loadFavoriteOverrideState());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_disposed) {
        _updateAppBarSolidProgress();
      }
    });
    unawaited(_recordHistory());
  }

  @override
  void dispose() {
    _disposed = true;
    _detailsTimeoutTimer?.cancel();
    _detailsTimeoutTimer = null;
    _tabController
      ..removeListener(_handleTabChanged)
      ..dispose();
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    _appBarSolidProgressNotifier.dispose();
    _collapsedTitleNotifier.dispose();
    super.dispose();
  }

  Future<void> ensureCommentsTabFullscreen() async {
    if (_disposed ||
        _tabController.index != 1 ||
        !_scrollController.hasClients ||
        _isAnimatingCommentsFullscreen) {
      return;
    }

    final position = _scrollController.position;
    final targetOffset = position.maxScrollExtent.clamp(0.0, double.infinity);
    final currentOffset = position.pixels.clamp(0.0, targetOffset);
    if (targetOffset <= 0 || currentOffset >= targetOffset - 1) return;

    _isAnimatingCommentsFullscreen = true;
    try {
      await _scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    } finally {
      _isAnimatingCommentsFullscreen = false;
    }
  }

  Map<String, Object?> buildCommentsTabDebugState() {
    final hasClients = _scrollController.hasClients;
    final position = hasClients ? _scrollController.position : null;
    return {
      'outerHasClients': hasClients,
      'outerPixels': position?.pixels.round(),
      'outerMinScrollExtent': position?.minScrollExtent.round(),
      'outerMaxScrollExtent': position?.maxScrollExtent.round(),
      'outerViewportDimension': position?.viewportDimension.round(),
      'outerAnimatingCommentsFullscreen': _isAnimatingCommentsFullscreen,
      'outerTabIndex': _tabController.index,
    };
  }

  void updateAppBarMetadata({
    required String title,
    required String updateTime,
  }) {
    if (_appBarComicTitle == title && _appBarUpdateTime == updateTime) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed) return;
      if (_appBarComicTitle == title && _appBarUpdateTime == updateTime) return;
      _appBarComicTitle = title;
      _appBarUpdateTime = updateTime;
      notifyListeners();
    });
  }

  void markComicDetailRevealHandled(ComicDetailsData details) {
    final primaryId = _comic.id.trim();
    final resolvedId = details.id.trim();
    if (primaryId.isNotEmpty) _animatedComicDetailIds.add(primaryId);
    if (resolvedId.isNotEmpty) _animatedComicDetailIds.add(resolvedId);
  }

  Future<void> loadReadingProgress() async {
    try {
      final progress = await _repository.loadReadingProgress(_comic.id);
      if (progress == null || _disposed) return;
      _lastReadProgress = progress;
      notifyListeners();
    } catch (_) {}
  }

  void _handleTabChanged() {
    final nextIndex = _tabController.index;
    if (_lastTabIndex == nextIndex) return;
    _lastTabIndex = nextIndex;
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _handleScroll() {
    _updateAppBarSolidProgress();
  }

  bool _updateAppBarSolidProgress() {
    if (!_scrollController.hasClients) return false;

    final offset = _scrollController.offset.clamp(0.0, double.infinity);
    const fadeStart = 72.0;
    const fadeDistance = 132.0;
    const titleCollapseEnterOffset = 198.0;
    const titleCollapseExitOffset = 162.0;

    final nextProgress = ((offset - fadeStart) / fadeDistance).clamp(0.0, 1.0);
    final wasCollapsed = _collapsedTitleNotifier.value;
    final titleCollapsed = wasCollapsed
        ? offset >= titleCollapseExitOffset
        : offset >= titleCollapseEnterOffset;

    final progressChanged =
        (_appBarSolidProgressNotifier.value - nextProgress).abs() >= 0.02;
    final titleChanged = titleCollapsed != _collapsedTitleNotifier.value;

    if (!progressChanged && !titleChanged) return false;

    if (progressChanged) _appBarSolidProgressNotifier.value = nextProgress;
    if (titleChanged) _collapsedTitleNotifier.value = titleCollapsed;
    return true;
  }

  Future<void> _loadFavoriteOverrideState() async {
    try {
      final details = await _future;
      final localFavorite = await _repository.isComicLocallyFavorited(
        details.id.trim().isNotEmpty ? details.id : _comic.id,
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
      if (details.chapters.isEmpty) return;
      final first = details.chapters.entries.first;
      final images = await _repository.loadChapterImages(
        comicId: details.id,
        epId: first.key,
      );
      await _repository.prefetchComicImages(
        comicId: details.id,
        epId: first.key,
        imageUrls: images,
        count: 3,
        memoryCount: 1,
      );
    } catch (_) {}
  }

  Future<ComicDetailsData> _createComicDetailsFuture() {
    final completer = Completer<ComicDetailsData>();
    final sourceFuture = _repository.loadComicDetails(_comic.id);

    _detailsTimeoutTimer = Timer(const Duration(seconds: 30), () {
      if (!completer.isCompleted) {
        completer.completeError(
          TimeoutException(
            'Timed out loading comic details for ${_comic.id}',
            const Duration(seconds: 30),
          ),
        );
      }
    });

    sourceFuture
        .then(
          (details) {
            if (!completer.isCompleted) completer.complete(details);
          },
          onError: (Object error, StackTrace stackTrace) {
            if (!completer.isCompleted) {
              completer.completeError(error, stackTrace);
            }
          },
        )
        .whenComplete(() {
          _detailsTimeoutTimer?.cancel();
          _detailsTimeoutTimer = null;
        });

    return completer.future;
  }
}
