part of '../reader_page.dart';

extension _ReaderNavigationActionsExtension on _ReaderPageState {
  KeyEventResult _handleReaderKeyEvent(FocusNode node, KeyEvent event) {
    if (!_volumeButtonTurnPage || event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.audioVolumeUp) {
      unawaited(_goToPreviousPage(trigger: 'keyboard_volume_up'));
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.audioVolumeDown) {
      unawaited(_goToNextPage(trigger: 'keyboard_volume_down'));
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Widget _buildReaderListView() {
    return NotificationListener<ScrollNotification>(
      onNotification: _handleReaderScrollNotification,
      child: ListView.builder(
        key: PageStorageKey<String>(
          'reader-list-${widget.comicId}-${widget.epId}-$_readerSpreadSize',
        ),
        padding: EdgeInsets.zero,
        cacheExtent: _readerListCacheExtent(context),
        itemCount: _readerSpreadCount,
        controller: _scrollController,
        physics: _zoomGestureActive
            ? const NeverScrollableScrollPhysics()
            : const _ReaderScrollPhysics(),
        itemBuilder: (context, index) => _buildReaderListItem(index),
      ),
    );
  }

  Widget _buildReaderPageImage(int imageIndex) {
    final url = _images[imageIndex];
    final cachedProvider = _providerCache[url];
    final readerSurfaceColor = _resolveReaderSurfaceColor(context);
    final readerPlaceholderColor = _resolveReaderPlaceholderColor(context);

    if (_noImageModeEnabled) {
      return const SizedBox.expand();
    }

    Widget buildImage(ImageProvider provider) {
      return _wrapImageWidget(
        ColoredBox(
          color: readerSurfaceColor,
          child: Center(
            child: Image(
              key: ValueKey('reader-page-$url'),
              image: provider,
              fit: BoxFit.contain,
              width: double.infinity,
              height: double.infinity,
              filterQuality: FilterQuality.medium,
              gaplessPlayback: true,
              frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                if (wasSynchronouslyLoaded || frame != null) {
                  return child;
                }
                return ColoredBox(color: readerSurfaceColor);
              },
              errorBuilder: (_, _, _) {
                return _buildReaderImageErrorView(
                  url,
                  backgroundColor: readerPlaceholderColor,
                );
              },
            ),
          ),
        ),
        url,
      );
    }

    if (cachedProvider != null) {
      return buildImage(cachedProvider);
    }

    return FutureBuilder<ImageProvider>(
      key: ValueKey('reader-page-future-$url'),
      future: _getOrCreateImageProviderFuture(url),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return buildImage(snapshot.data!);
        }
        if (snapshot.hasError) {
          return _buildReaderImageErrorView(
            url,
            backgroundColor: readerPlaceholderColor,
          );
        }
        return ColoredBox(
          color: readerSurfaceColor,
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        );
      },
    );
  }

  Widget _buildReaderPageSpread(int spreadIndex) {
    final imageIndices = _spreadImageIndices(spreadIndex);
    if (imageIndices.isEmpty) {
      return const SizedBox.expand();
    }

    final spreadContent = imageIndices.length == 1
        ? _buildReaderPageImage(imageIndices.first)
        : Row(
            children: [
              Expanded(child: _buildReaderPageImage(imageIndices[0])),
              Expanded(child: _buildReaderPageImage(imageIndices[1])),
            ],
          );

    return _wrapPageWithPinchZoom(index: spreadIndex, child: spreadContent);
  }

  Widget _buildReaderPageView() {
    return PageView.builder(
      key: PageStorageKey<String>(
        'reader-page-${widget.comicId}-${widget.epId}-rtl-$_readerSpreadSize',
      ),
      controller: _pageController,
      reverse: false,
      allowImplicitScrolling: true,
      itemCount: _readerSpreadCount,
      physics: _pageNavigationLocked
          ? const NeverScrollableScrollPhysics()
          : const PageScrollPhysics(),
      onPageChanged: (index) {
        if (_pageNavigationLocked) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted ||
                !_pageController.hasClients ||
                _currentPageIndex == index) {
              return;
            }
            _pageController.jumpToPage(_currentPageIndex);
          });
          return;
        }
        final pageChanged = _currentPageIndex != index;
        final zoomWasActive = _isZoomed;
        _resetZoomImmediately(reason: 'page_swipe');
        if (pageChanged || zoomWasActive) {
          _updateReaderState(() {
            _currentPageIndex = index;
          });
        }
        _setDisplayedPageIndex(index);
        _logVisiblePageChange(index: index, trigger: 'page_swipe');
        if (!_noImageModeEnabled) {
          _prefetchAround(index);
          _requestPrefetchAhead(index);
        }
      },
      itemBuilder: (context, index) {
        return _buildReaderPageSpread(index);
      },
    );
  }

  Future<void> _scrollToListReaderPage(
    int index, {
    bool animate = true,
    String trigger = 'manual',
  }) async {
    if (!_scrollController.hasClients || _readerSpreadCount <= 0) {
      _logReaderEvent(
        'Reader list scroll skipped',
        level: 'warning',
        source: 'reader_navigation',
        content: _readerLogPayload({
          'trigger': trigger,
          'reason': !_scrollController.hasClients
              ? 'scroll_controller_has_no_clients'
              : 'images_empty',
          'targetPageIndex': index,
          'animate': animate,
        }),
      );
      return;
    }
    final target = _normalizeSpreadIndex(index);
    final visibleContext = target < _itemKeys.length
        ? _itemKeys[target].currentContext
        : null;
    _diagnosticsState.activeProgrammaticListScrollReason = trigger;
    _diagnosticsState.activeProgrammaticListTargetIndex = target;
    try {
      if (visibleContext != null) {
        await Scrollable.ensureVisible(
          visibleContext,
          duration: animate ? const Duration(milliseconds: 360) : Duration.zero,
          curve: Curves.easeOutCubic,
          alignment: 0,
        );
        if (!mounted) {
          return;
        }
        _markProgrammaticListScrollCompleted(target);
        return;
      }

      final maxScrollExtent = _scrollController.position.maxScrollExtent;
      final ratio = _readerSpreadCount <= 1
          ? 0.0
          : target / (_readerSpreadCount - 1);
      final estimatedOffset = math.max(
        0.0,
        math.min(maxScrollExtent * ratio, maxScrollExtent),
      );
      if (animate) {
        await _scrollController.animateTo(
          estimatedOffset,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        );
      } else {
        _scrollController.jumpTo(estimatedOffset);
      }

      if (!mounted) {
        return;
      }
      _markProgrammaticListScrollCompleted(target);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        final exactContext = target < _itemKeys.length
            ? _itemKeys[target].currentContext
            : null;
        if (exactContext == null) {
          _logReaderEvent(
            'Reader list exact alignment skipped',
            level: 'warning',
            source: 'reader_navigation',
            content: _readerLogPayload({
              'trigger': '${trigger}_post_frame_exact_alignment',
              'targetPageIndex': target,
              'targetPage': target + 1,
              'reason': 'target_context_not_available_after_estimated_scroll',
              'animate': animate,
            }),
          );
          return;
        }
        _diagnosticsState.activeProgrammaticListScrollReason =
            '${trigger}_post_frame_exact_alignment';
        _diagnosticsState.activeProgrammaticListTargetIndex = target;
        unawaited(
          Scrollable.ensureVisible(
            exactContext,
            duration: animate
                ? const Duration(milliseconds: 220)
                : Duration.zero,
            curve: Curves.easeOutCubic,
            alignment: 0,
          ).then((_) {
            _diagnosticsState.activeProgrammaticListScrollReason = null;
            _diagnosticsState.activeProgrammaticListTargetIndex = null;
            _markProgrammaticListScrollCompleted(target);
          }),
        );
      });
    } finally {
      _diagnosticsState.activeProgrammaticListScrollReason = null;
      _diagnosticsState.activeProgrammaticListTargetIndex = null;
    }
  }

  Future<void> _goToReaderPage(int index, {String trigger = 'manual'}) async {
    if (_readerSpreadCount <= 0) {
      return;
    }
    final target = _normalizeSpreadIndex(index);
    _logReaderEvent(
      'Reader page navigation requested',
      source: 'reader_navigation',
      content: _readerLogPayload({
        'trigger': trigger,
        'fromPageIndex': _currentPageIndex,
        'fromPage': _readerSpreadCount <= 0
            ? 0
            : math.min(_currentPageIndex + 1, _readerSpreadCount),
        'targetPageIndex': target,
        'targetPage': target + 1,
      }),
    );
    _setDisplayedPageIndex(target);
    if (_readerMode == ReaderMode.rightToLeft) {
      if (!_pageController.hasClients || target == _currentPageIndex) {
        return;
      }
      _resetZoomImmediately(reason: 'page_navigation_request');
      await _pageController.animateToPage(
        target,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    await _scrollToListReaderPage(target, trigger: trigger);
  }

  Future<void> _goToPreviousPage({String trigger = 'tap_previous_zone'}) async {
    if (_currentPageIndex <= 0) {
      return;
    }
    await _goToReaderPage(_currentPageIndex - 1, trigger: trigger);
  }

  Future<void> _goToNextPage({String trigger = 'tap_next_zone'}) async {
    if (_currentPageIndex >= _readerSpreadCount - 1) {
      return;
    }
    await _goToReaderPage(_currentPageIndex + 1, trigger: trigger);
  }

  Widget _wrapReaderTapPaging(Widget child) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tapPagingEnabled =
            _readerMode == ReaderMode.rightToLeft && _tapToTurnPage;
        final leftTriggerWidth = constraints.maxWidth * 0.25;
        final rightTriggerStart = constraints.maxWidth * 0.75;
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapUp: (details) {
            if (_activePointerCount > 1) {
              return;
            }
            final dx = details.localPosition.dx;
            final isCenterTap = dx > leftTriggerWidth && dx < rightTriggerStart;
            if (tapPagingEnabled && !_pageNavigationLocked) {
              if (dx <= leftTriggerWidth) {
                unawaited(_goToPreviousPage());
                return;
              }
              if (dx >= rightTriggerStart) {
                unawaited(_goToNextPage());
                return;
              }
            }
            if (isCenterTap) {
              _toggleControlsVisibility();
            }
          },
          child: child,
        );
      },
    );
  }
}
