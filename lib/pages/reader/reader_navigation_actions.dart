part of '../reader_page.dart';

extension _ReaderNavigationActionsExtension on _ReaderPageState {
  Widget _buildReaderListView() {
    return NotificationListener<ScrollNotification>(
      onNotification: _handleReaderScrollNotification,
      child: ListView.builder(
        key: PageStorageKey<String>('reader-list-${widget.comicId}-${widget.epId}'),
        padding: EdgeInsets.zero,
        cacheExtent: _readerListCacheExtent(context),
        itemCount: _images.length,
        controller: _scrollController,
        physics: _zoomGestureActive
            ? const NeverScrollableScrollPhysics()
            : const _ReaderScrollPhysics(),
        itemBuilder: (context, index) => _buildReaderListItem(index),
      ),
    );
  }

  Widget _buildReaderPageView() {
    return PageView.builder(
      key: PageStorageKey<String>('reader-page-${widget.comicId}-${widget.epId}-rtl'),
      controller: _pageController,
      reverse: false,
      allowImplicitScrolling: true,
      itemCount: _images.length,
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
        final url = _images[index];
        final cachedProvider = _providerCache[url];

        if (_noImageModeEnabled) {
          return const SizedBox.expand();
        }

        Widget buildImage(ImageProvider provider) {
          return _wrapImageWidget(
            _wrapPageWithPinchZoom(
              index: index,
              child: ColoredBox(
                color: Colors.black,
                child: Center(
                  child: Image(
                    key: ValueKey('reader-page-$url'),
                    image: provider,
                    fit: BoxFit.contain,
                    width: double.infinity,
                    height: double.infinity,
                    filterQuality: FilterQuality.medium,
                    gaplessPlayback: true,
                    frameBuilder:
                        (context, child, frame, wasSynchronouslyLoaded) {
                          if (wasSynchronouslyLoaded || frame != null) {
                            return child;
                          }
                          return const ColoredBox(color: Colors.black);
                        },
                    errorBuilder: (_, _, _) {
                      return Container(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        alignment: Alignment.center,
                        child: const Icon(Icons.broken_image_outlined),
                      );
                    },
                  ),
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
              return Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                alignment: Alignment.center,
                child: const Icon(Icons.broken_image_outlined),
              );
            }
            return const ColoredBox(
              color: Colors.black,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          },
        );
      },
    );
  }

  Future<void> _scrollToListReaderPage(
    int index, {
    bool animate = true,
    String trigger = 'manual',
  }) async {
    if (!_scrollController.hasClients || _images.isEmpty) {
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
    final target = math.max(0, math.min(index, _images.length - 1));
    final previousPixels = _scrollController.position.pixels;
    final visibleContext = target < _itemKeys.length
        ? _itemKeys[target].currentContext
        : null;
    _diagnosticsState.activeProgrammaticListScrollReason = trigger;
    _diagnosticsState.activeProgrammaticListTargetIndex = target;
    _logListPositionSnapshot(
      'Reader list programmatic scroll started',
      trigger: trigger,
      previousPixels: previousPixels,
      normalizedIndex: target,
      extra: {
        'targetPageIndex': target,
        'targetPage': target + 1,
        'animate': animate,
        'hasVisibleContext': visibleContext != null,
      },
    );
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
        _logListPositionSnapshot(
          'Reader list programmatic scroll finished',
          trigger: '${trigger}_ensure_visible',
          previousPixels: previousPixels,
          normalizedIndex: target,
          extra: {
            'targetPageIndex': target,
            'targetPage': target + 1,
            'path': 'ensure_visible',
            'animate': animate,
          },
        );
        return;
      }

      final maxScrollExtent = _scrollController.position.maxScrollExtent;
      final ratio = _images.length <= 1 ? 0.0 : target / (_images.length - 1);
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
      _logListPositionSnapshot(
        'Reader list approximate scroll applied',
        trigger: '${trigger}_estimated_offset',
        previousPixels: previousPixels,
        normalizedIndex: target,
        extra: {
          'targetPageIndex': target,
          'targetPage': target + 1,
          'path': animate
              ? 'animate_to_estimated_offset'
              : 'jump_to_estimated_offset',
          'estimatedOffset': _normalizeLogDouble(estimatedOffset),
          'animate': animate,
        },
      );

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
            if (!mounted) {
              return;
            }
            _logListPositionSnapshot(
              'Reader list exact alignment applied',
              trigger: '${trigger}_post_frame_exact_alignment',
              previousPixels: previousPixels,
              normalizedIndex: target,
              extra: {
                'targetPageIndex': target,
                'targetPage': target + 1,
                'path': 'post_frame_ensure_visible',
                'animate': animate,
              },
            );
          }),
        );
      });
    } finally {
      _diagnosticsState.activeProgrammaticListScrollReason = null;
      _diagnosticsState.activeProgrammaticListTargetIndex = null;
    }
  }

  Future<void> _goToReaderPage(int index, {String trigger = 'manual'}) async {
    if (_images.isEmpty) {
      return;
    }
    final target = math.max(0, math.min(index, _images.length - 1));
    _logReaderEvent(
      'Reader page navigation requested',
      source: 'reader_navigation',
      content: _readerLogPayload({
        'trigger': trigger,
        'fromPageIndex': _currentPageIndex,
        'fromPage': _images.isEmpty
            ? 0
            : math.min(_currentPageIndex + 1, _images.length),
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

  Future<void> _goToPreviousPage() async {
    if (_currentPageIndex <= 0) {
      return;
    }
    await _goToReaderPage(_currentPageIndex - 1, trigger: 'tap_previous_zone');
  }

  Future<void> _goToNextPage() async {
    if (_currentPageIndex >= _images.length - 1) {
      return;
    }
    await _goToReaderPage(_currentPageIndex + 1, trigger: 'tap_next_zone');
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
