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

  late final Future<ComicDetailsData> _future;
  Timer? _detailsTimeoutTimer;
  Map<String, dynamic>? _lastReadProgress;

  Future<ComicDetailsData> get future => _future;
  Map<String, dynamic>? get lastReadProgress => _lastReadProgress;

  void initialize() {
    _future = _createComicDetailsFuture();
    unawaited(_warmupReaderImages());
    unawaited(loadReadingProgress());
    unawaited(_loadFavoriteOverrideState());
    unawaited(_recordHistory());
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

  Future<ComicDetailsData> _createComicDetailsFuture() {
    final completer = Completer<ComicDetailsData>();
    final sourceFuture = _repository.loadComicDetails(
      _comic.id,
      sourceKey: _sourceKey,
    );

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
