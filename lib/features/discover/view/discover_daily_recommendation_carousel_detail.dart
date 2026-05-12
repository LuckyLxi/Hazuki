part of 'discover_daily_recommendation_carousel.dart';

extension _DiscoverDailyRecommendationCarouselDetail
    on _DiscoverDailyRecommendationCarouselState {
  void _attachRouteAnimationIfNeeded() {
    final route = ModalRoute.of(context);
    final nextSecondaryAnimation = route?.secondaryAnimation;
    if (identical(nextSecondaryAnimation, _routeSecondaryAnimation)) {
      _syncOverlayHeroTagWithRoute();
      return;
    }
    _detachRouteAnimation();
    _routeSecondaryAnimation = nextSecondaryAnimation;
    _routeSecondaryAnimation?.addStatusListener(_handleRouteStatusChanged);
    _syncOverlayHeroTagWithRoute();
  }

  void _detachRouteAnimation() {
    _routeSecondaryAnimation?.removeStatusListener(_handleRouteStatusChanged);
    _routeSecondaryAnimation = null;
  }

  void _handleRouteStatusChanged(AnimationStatus _) {
    if (!mounted) {
      return;
    }
    _syncOverlayHeroTagWithRoute();
  }

  void _syncOverlayHeroTagWithRoute() {
    if (_detailOpen || _activeOverlayHeroTag == null) {
      return;
    }
    final secondaryAnimation = _routeSecondaryAnimation;
    if (secondaryAnimation != null &&
        secondaryAnimation.status != AnimationStatus.dismissed) {
      return;
    }
    _scheduleOverlayReveal();
  }

  void _scheduleOverlayReveal({
    Duration delay = Duration.zero,
    String? trigger,
  }) {
    _overlayRevealTimer?.cancel();
    if (_activeOverlayHeroTag == null) {
      return;
    }
    if (delay <= Duration.zero) {
      if (!mounted) {
        _activeOverlayHeroTag = null;
      } else {
        _setCarouselState(() {
          _activeOverlayHeroTag = null;
        });
      }
      return;
    }
    _overlayRevealTimer = Timer(delay, () {
      if (!mounted || _detailOpen || _activeOverlayHeroTag == null) {
        return;
      }
      _setCarouselState(() {
        _activeOverlayHeroTag = null;
      });
      if (trigger != null) {
        _logCarouselEvent(
          'Discover carousel overlay restored',
          content: {'trigger': trigger, 'logicalPage': _currentPage},
        );
      }
    });
  }

  Future<void> _openRecommendation(
    BuildContext context,
    DiscoverDailyRecommendationEntry entry,
    String heroTag,
  ) async {
    if (_detailOpen) {
      return;
    }
    _overlayRevealTimer?.cancel();
    if (mounted) {
      _setCarouselState(() {
        _detailOpen = true;
        _activeOverlayHeroTag = heroTag;
      });
    } else {
      _detailOpen = true;
      _activeOverlayHeroTag = heroTag;
    }
    _logCarouselEvent(
      'Discover carousel recommendation opening',
      content: {
        'heroTag': heroTag,
        'logicalPage': _currentPage,
        'comicId': entry.comic.id,
        'comicTitle': entry.comic.title,
      },
    );
    _cancelAutoPlay(trigger: 'open_recommendation', reason: 'detail_open');
    try {
      await openComicDetail(
        context,
        comic: entry.comic,
        heroTag: heroTag,
        pageBuilder: widget.comicDetailPageBuilder,
      );
    } finally {
      final keepDetailOpen =
          useWindowsComicDetailPanel && _windowsController.isOpen;
      if (!keepDetailOpen && mounted) {
        _setCarouselState(() {
          _detailOpen = false;
        });
        _logCarouselEvent(
          'Discover carousel recommendation closed',
          content: {
            'heroTag': heroTag,
            'logicalPage': _currentPage,
            'comicId': entry.comic.id,
          },
        );
        _syncOverlayHeroTagWithRoute();
        _startAutoPlay(trigger: 'detail_closed');
      } else if (!keepDetailOpen) {
        _detailOpen = false;
      }
    }
  }

  void _handleWindowsDetailControllerChanged() {
    final controller = _windowsController;
    final panelOpen = controller.isOpen;
    final closedHeroTag = !panelOpen ? _activeOverlayHeroTag : null;
    if (_detailOpen == panelOpen &&
        (panelOpen || _activeOverlayHeroTag == null)) {
      return;
    }
    if (!mounted) {
      _detailOpen = panelOpen;
      if (!panelOpen) {
        _scheduleOverlayReveal(
          delay: windowsComicDetailPanelAnimationDuration,
          trigger: 'windows_detail_closed',
        );
      }
      return;
    }
    if (panelOpen) {
      _overlayRevealTimer?.cancel();
    }
    _setCarouselState(() {
      _detailOpen = panelOpen;
    });
    if (!panelOpen) {
      _scheduleOverlayReveal(
        delay: windowsComicDetailPanelAnimationDuration,
        trigger: 'windows_detail_closed',
      );
      _logCarouselEvent(
        'Discover carousel recommendation closed',
        content: {'heroTag': closedHeroTag, 'logicalPage': _currentPage},
      );
      _startAutoPlay(trigger: 'windows_detail_closed');
    }
  }
}
