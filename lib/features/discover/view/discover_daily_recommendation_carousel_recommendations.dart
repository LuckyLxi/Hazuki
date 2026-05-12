part of 'discover_daily_recommendation_carousel.dart';

extension _DiscoverDailyRecommendationCarouselRecommendations
    on _DiscoverDailyRecommendationCarouselState {
  void _replaceDisplayedRecommendations(
    List<DiscoverDailyRecommendationEntry> recommendations,
  ) {
    _displayedRecommendations =
        List<DiscoverDailyRecommendationEntry>.unmodifiable(recommendations);
    _displayedSnapshotKey = _snapshotKey(_displayedRecommendations);
    _prefetchedCoverIndexes.clear();
    _reportedCardSnapshots.clear();
    _reportedImageStates.clear();
    _currentPage = _recommendationCount == 0
        ? 0
        : _normalizeLogicalPage(_currentPage);
  }

  void _clearPendingRecommendations() {
    _pendingRecommendations = const <DiscoverDailyRecommendationEntry>[];
    _pendingSnapshotKey = '';
    _usingMixedSnapshots = false;
    _pendingActivationScheduled = false;
    _protectedVisibleItems.clear();
  }

  String _snapshotKey(List<DiscoverDailyRecommendationEntry> recommendations) {
    return discoverDailyRecommendationSnapshotKey(recommendations);
  }

  void _schedulePendingActivation({required String trigger}) {
    if (_pendingActivationScheduled) {
      return;
    }
    _pendingActivationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pendingActivationScheduled = false;
      if (!mounted) {
        return;
      }
      _activatePendingRecommendations(trigger: trigger);
    });
  }

  void _activatePendingRecommendations({required String trigger}) {
    if (_usingMixedSnapshots ||
        !_hasPendingRecommendations ||
        _displayedRecommendations.isEmpty) {
      return;
    }
    if (_pendingSnapshotKey == _displayedSnapshotKey) {
      _completePendingPromotion(trigger: '${trigger}_same_snapshot');
      return;
    }
    final protectedVisibleItems = _computeVisibleLogicalItems();
    if (protectedVisibleItems.isEmpty && _recommendationCount > 0) {
      protectedVisibleItems.add(_normalizeLogicalPage(_currentPage));
    }
    _setCarouselState(() {
      _usingMixedSnapshots = true;
      _protectedVisibleItems
        ..clear()
        ..addAll(protectedVisibleItems);
    });
    _logCarouselEvent(
      'Discover carousel pending recommendations activated',
      content: {
        'trigger': trigger,
        'protectedVisibleItems': protectedVisibleItems.toList()..sort(),
      },
    );
  }

  void _scheduleProtectedItemRelease({required String trigger}) {
    if (!_usingMixedSnapshots) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _releaseOffscreenProtectedItems(trigger: trigger);
    });
  }

  void _releaseOffscreenProtectedItems({required String trigger}) {
    if (!_usingMixedSnapshots || !_hasPendingRecommendations) {
      return;
    }
    final visibleLogicalItems = _computeVisibleLogicalItems();
    final releasedItems = _protectedVisibleItems
        .where((index) => !visibleLogicalItems.contains(index))
        .toList(growable: false);
    if (releasedItems.isNotEmpty) {
      _setCarouselState(() {
        _protectedVisibleItems.removeAll(releasedItems);
      });
      _logCarouselEvent(
        'Discover carousel protected items released',
        content: {
          'trigger': trigger,
          'releasedItems': releasedItems,
          'remainingProtectedItems': _protectedVisibleItems.toList()..sort(),
        },
      );
    }
    if (_protectedVisibleItems.isEmpty) {
      _completePendingPromotion(trigger: '${trigger}_promotion');
    }
  }

  void _completePendingPromotion({required String trigger}) {
    if (!_hasPendingRecommendations) {
      return;
    }
    final nextRecommendations = _pendingRecommendations;
    _setCarouselState(() {
      _replaceDisplayedRecommendations(nextRecommendations);
      _clearPendingRecommendations();
    });
    _warmUpRecommendationCovers(_currentPage);
    unawaited(_recommendationService.promotePendingRecommendations());
    _logCarouselEvent(
      'Discover carousel pending recommendations promoted',
      content: {'trigger': trigger},
    );
  }

  Set<int> _computeVisibleLogicalItems() {
    if (_recommendationCount == 0) {
      return <int>{};
    }
    final heroCardWidth = _lastHeroCardWidth;
    final pageExtent = _lastPageExtent;
    final viewportWidth = _lastViewportWidth;
    if (heroCardWidth == null || pageExtent == null || viewportWidth == null) {
      return <int>{_normalizeLogicalPage(_currentPage)};
    }
    final visibleLogicalItems = <int>{};
    final page = _pageController.hasClients
        ? (_pageController.page ??
              _physicalPageForLogical(_currentPage).toDouble())
        : _physicalPageForLogical(_currentPage).toDouble();
    final start = math.max(0, page.floor() - 2);
    final end = math.min(_loopedItemCount - 1, page.ceil() + 3);
    for (var physicalIndex = start; physicalIndex <= end; physicalIndex++) {
      final metrics = _buildCardLayoutMetrics(
        delta: physicalIndex - page,
        heroCardWidth: heroCardWidth,
        pageExtent: pageExtent,
      );
      if (metrics.visibleWidth(
            heroCardWidth: heroCardWidth,
            viewportWidth: viewportWidth,
          ) <=
          0.5) {
        continue;
      }
      visibleLogicalItems.add(_logicalPageForPhysical(physicalIndex));
    }
    return visibleLogicalItems;
  }

  List<int> _coverWarmUpOrder(int anchorLogicalPage) {
    return _loopMetrics.coverWarmUpOrder(anchorLogicalPage);
  }

  void _warmUpRecommendationCovers(int anchorLogicalPage) {
    if (_recommendationCount == 0) {
      return;
    }
    for (final index in _coverWarmUpOrder(anchorLogicalPage)) {
      if (!_prefetchedCoverIndexes.add(index)) {
        continue;
      }
      unawaited(_prefetchRecommendationCover(index));
    }
  }

  Future<void> _prefetchRecommendationCover(int logicalIndex) async {
    final normalizedIndex = _normalizeLogicalPage(logicalIndex);
    final coverUrl = _resolvedRecommendationEntry(
      normalizedIndex,
    ).comic.cover.trim();
    final sourceKey = _resolvedRecommendationEntry(
      normalizedIndex,
    ).comic.sourceKey;
    if (coverUrl.isEmpty) {
      return;
    }
    try {
      final bytes = await _sourceService.downloadImageBytes(
        coverUrl,
        keepInMemory: true,
        sourceKey: sourceKey,
      );
      putHazukiWidgetImageMemory(coverUrl, bytes, sourceKey: sourceKey);
    } catch (_) {
      _prefetchedCoverIndexes.remove(normalizedIndex);
    }
  }

  DiscoverDailyRecommendationEntry _resolvedRecommendationEntry(
    int logicalIndex,
  ) {
    final normalizedIndex = _normalizeLogicalPage(logicalIndex);
    if (_usingMixedSnapshots &&
        _hasPendingRecommendations &&
        !_protectedVisibleItems.contains(normalizedIndex) &&
        normalizedIndex < _pendingRecommendations.length) {
      return _pendingRecommendations[normalizedIndex];
    }
    return _displayedRecommendations[normalizedIndex];
  }
}
