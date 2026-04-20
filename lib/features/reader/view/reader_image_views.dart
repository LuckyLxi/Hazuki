part of 'reader_page.dart';

extension _ReaderPageStateImageViews on _ReaderPageState {
  ThemeData _resolveReaderTheme([BuildContext? buildContext]) {
    final targetContext = buildContext ?? context;
    return widget.comicTheme ?? Theme.of(targetContext);
  }

  Color _resolveReaderSurfaceColor([BuildContext? buildContext]) {
    return _resolveReaderTheme(buildContext).colorScheme.surface;
  }

  Color _resolveReaderPlaceholderColor([BuildContext? buildContext]) {
    return _resolveReaderTheme(
      buildContext,
    ).colorScheme.surfaceContainerHighest;
  }

  Widget _buildZoomableReader({
    required Widget child,
    bool constrained = true,
  }) {
    return InteractiveViewer(
      transformationController: _zoomController,
      panEnabled: _runtimeState.isZoomed || _runtimeState.zoomInteracting,
      scaleEnabled: true,
      panAxis: PanAxis.free,
      boundaryMargin: EdgeInsets.zero,
      constrained: constrained,
      clipBehavior: Clip.hardEdge,
      minScale: 1.0,
      maxScale: 5.0,
      onInteractionStart: _readerZoomController.handleInteractionStart,
      onInteractionUpdate: _readerZoomController.handleInteractionUpdate,
      onInteractionEnd: _readerZoomController.handleInteractionEnd,
      child: child,
    );
  }

  Widget _wrapPageWithPinchZoom({required int index, required Widget child}) {
    if (!_runtimeState.pinchToZoom ||
        _runtimeState.readerMode != ReaderMode.rightToLeft ||
        index != _runtimeState.currentPageIndex) {
      return child;
    }
    return _buildZoomableReader(child: child);
  }

  Widget _buildReaderListView() {
    return NotificationListener<ScrollNotification>(
      onNotification: _navigationController.handleScrollNotification,
      child: ListView.builder(
        key: PageStorageKey<String>(
          'reader-list-${widget.comicId}-${widget.epId}-${_runtimeState.readerSpreadSize}',
        ),
        padding: EdgeInsets.zero,
        cacheExtent: _imagePipelineController.readerListCacheExtent(context),
        itemCount: _runtimeState.readerSpreadCount,
        controller: _scrollController,
        physics: _runtimeState.zoomGestureActive
            ? const NeverScrollableScrollPhysics()
            : const _ReaderScrollPhysics(),
        itemBuilder: (context, index) => _buildReaderListItem(index),
      ),
    );
  }

  Widget _buildReaderPageImage(int imageIndex) {
    final url = _runtimeState.images[imageIndex];
    final cachedProvider = _imagePipelineController.cachedProviderFor(url);
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
      future: _imagePipelineController.getImageProvider(url),
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
    final imageIndices = _runtimeState.spreadImageIndices(spreadIndex);
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
        'reader-page-${widget.comicId}-${widget.epId}-rtl-${_runtimeState.readerSpreadSize}',
      ),
      controller: _pageController,
      reverse: false,
      allowImplicitScrolling: true,
      itemCount: _runtimeState.readerSpreadCount,
      physics: _runtimeState.pageNavigationLocked
          ? const NeverScrollableScrollPhysics()
          : const PageScrollPhysics(),
      onPageChanged: _navigationController.handlePageChanged,
      itemBuilder: (context, index) {
        return _buildReaderPageSpread(index);
      },
    );
  }

  Widget _buildTopToBottomReaderView() {
    if (!_runtimeState.pinchToZoom ||
        _runtimeState.readerMode != ReaderMode.topToBottom) {
      return _buildReaderListView();
    }
    return _buildZoomableReader(child: _buildReaderListView());
  }

  Widget _wrapReaderTapPaging(Widget child) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapUp: (details) {
            unawaited(
              _navigationController.handleTapUp(details, constraints.maxWidth),
            );
          },
          child: child,
        );
      },
    );
  }

  Widget _buildReaderListItem(int spreadIndex) {
    final imageIndices = _runtimeState.spreadImageIndices(spreadIndex);
    if (imageIndices.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      key: spreadIndex < _runtimeState.itemKeys.length
          ? _runtimeState.itemKeys[spreadIndex]
          : null,
      child: imageIndices.length == 1
          ? _buildReaderListImage(imageIndices.first)
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildReaderListImage(imageIndices[0])),
                Expanded(child: _buildReaderListImage(imageIndices[1])),
              ],
            ),
    );
  }

  Widget _buildReaderListImage(int imageIndex) {
    final url = _runtimeState.images[imageIndex];
    final cachedProvider = _imagePipelineController.cachedProviderFor(url);
    final readerSurfaceColor = _resolveReaderSurfaceColor(context);
    final readerPlaceholderColor = _resolveReaderPlaceholderColor(context);

    double? currentResolvedAspectRatio() {
      return _imagePipelineState.imageAspectRatioCache[url];
    }

    double currentPlaceholderAspectRatio() {
      return currentResolvedAspectRatio() ??
          _imagePipelineController.resolvePlaceholderAspectRatio(imageIndex);
    }

    if (_noImageModeEnabled) {
      return AspectRatio(
        aspectRatio: currentPlaceholderAspectRatio(),
        child: const SizedBox.expand(),
      );
    }

    Widget buildImageError({required bool stableAspectRatio}) {
      final errorView = _buildReaderImageErrorView(
        url,
        compact: true,
        backgroundColor: readerPlaceholderColor,
      );
      if (!stableAspectRatio) {
        return errorView;
      }
      return ColoredBox(
        color: readerSurfaceColor,
        child: AspectRatio(
          aspectRatio: currentPlaceholderAspectRatio(),
          child: errorView,
        ),
      );
    }

    Widget buildImage(ImageProvider provider) {
      final resolvedAspectRatio = currentResolvedAspectRatio();
      final image = Image(
        key: ValueKey(url),
        image: provider,
        fit: resolvedAspectRatio != null ? BoxFit.fill : BoxFit.fitWidth,
        width: double.infinity,
        height: resolvedAspectRatio != null ? double.infinity : null,
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded || frame != null) {
            return child;
          }
          return ColoredBox(color: readerSurfaceColor);
        },
        errorBuilder: (_, _, _) {
          return buildImageError(stableAspectRatio: false);
        },
      );
      final stableImage = resolvedAspectRatio == null
          ? image
          : ColoredBox(
              color: readerSurfaceColor,
              child: AspectRatio(
                aspectRatio: resolvedAspectRatio,
                child: image,
              ),
            );
      return _wrapImageWidget(stableImage, url);
    }

    if (cachedProvider != null) {
      return buildImage(cachedProvider);
    }

    return FutureBuilder<ImageProvider>(
      key: ValueKey(url),
      future: _imagePipelineController.getImageProvider(url),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return buildImage(snapshot.data!);
        }
        if (snapshot.hasError) {
          return AspectRatio(
            aspectRatio: currentPlaceholderAspectRatio(),
            child: buildImageError(stableAspectRatio: false),
          );
        }
        return AspectRatio(
          aspectRatio: currentPlaceholderAspectRatio(),
          child: DecoratedBox(
            decoration: BoxDecoration(color: readerSurfaceColor),
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      },
    );
  }

  Widget _buildReaderImageErrorView(
    String url, {
    bool compact = false,
    Color? backgroundColor,
  }) {
    final isRetrying = _imagePipelineController.isRetrying(url);
    final theme = Theme.of(context);
    final surfaceColor = backgroundColor ?? _resolveReaderPlaceholderColor();
    final foregroundColor = theme.colorScheme.onSurfaceVariant;

    return ColoredBox(
      color: surfaceColor,
      child: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 12 : 20,
            vertical: compact ? 16 : 24,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: compact ? 220 : 320),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.broken_image_outlined,
                  color: foregroundColor,
                  size: compact ? 28 : 36,
                ),
                SizedBox(height: compact ? 10 : 14),
                FilledButton.tonalIcon(
                  onPressed: isRetrying
                      ? null
                      : () =>
                            unawaited(_imagePipelineController.retryImage(url)),
                  icon: isRetrying
                      ? SizedBox(
                          width: compact ? 14 : 16,
                          height: compact ? 14 : 16,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.refresh_rounded),
                  label: Text(l10n(context).commonRetry),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
