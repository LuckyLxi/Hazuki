import 'dart:async';

import 'package:flutter/material.dart';

import 'package:hazuki/features/reader/reader.dart';
import 'package:hazuki/features/reader/state/reader_image_pipeline_state.dart';
import 'package:hazuki/features/reader/state/reader_runtime_state.dart';
import 'package:hazuki/features/reader/support/reader_image_pipeline_controller.dart';
import 'package:hazuki/features/reader/support/reader_navigation_controller.dart';
import 'package:hazuki/features/reader/support/reader_zoom_controller.dart';
import 'package:hazuki/l10n/l10n.dart';

class ReaderImageViews {
  const ReaderImageViews({
    required this.context,
    required this.comicId,
    required this.epId,
    required this.comicTheme,
    required this.runtimeState,
    required this.imagePipelineState,
    required this.zoomController,
    required this.imagePipelineController,
    required this.navigationController,
    required this.scrollController,
    required this.pageController,
    required this.readerZoomController,
    required this.wrapImageWidget,
    required this.noImageModeEnabled,
  });

  final BuildContext context;
  final String comicId;
  final String epId;
  final ThemeData? comicTheme;
  final ReaderRuntimeState runtimeState;
  final ReaderImagePipelineState imagePipelineState;
  final TransformationController zoomController;
  final ReaderImagePipelineController imagePipelineController;
  final ReaderNavigationController navigationController;
  final ScrollController scrollController;
  final PageController pageController;
  final ReaderZoomController readerZoomController;
  final Widget Function(Widget imageWidget, String url) wrapImageWidget;
  final bool noImageModeEnabled;

  ThemeData resolveReaderTheme([BuildContext? buildContext]) {
    final targetContext = buildContext ?? context;
    return comicTheme ?? Theme.of(targetContext);
  }

  Color _resolveReaderSurfaceColor([BuildContext? buildContext]) {
    return resolveReaderTheme(buildContext).colorScheme.surface;
  }

  Color _resolveReaderPlaceholderColor([BuildContext? buildContext]) {
    return resolveReaderTheme(buildContext).colorScheme.surfaceContainerHighest;
  }

  Widget _buildZoomableReader({
    required Widget child,
    bool constrained = true,
  }) {
    return InteractiveViewer(
      transformationController: zoomController,
      panEnabled: runtimeState.isZoomed || runtimeState.zoomInteracting,
      scaleEnabled: true,
      panAxis: PanAxis.free,
      boundaryMargin: EdgeInsets.zero,
      constrained: constrained,
      clipBehavior: Clip.hardEdge,
      minScale: 1.0,
      maxScale: 5.0,
      onInteractionStart: readerZoomController.handleInteractionStart,
      onInteractionUpdate: readerZoomController.handleInteractionUpdate,
      onInteractionEnd: readerZoomController.handleInteractionEnd,
      child: child,
    );
  }

  Widget _wrapPageWithPinchZoom({required int index, required Widget child}) {
    if (!runtimeState.pinchToZoom ||
        runtimeState.readerMode != ReaderMode.rightToLeft ||
        index != runtimeState.currentPageIndex) {
      return child;
    }
    return _buildZoomableReader(child: child);
  }

  Widget _buildReaderListView() {
    return NotificationListener<ScrollNotification>(
      onNotification: navigationController.handleScrollNotification,
      child: ListView.builder(
        key: PageStorageKey<String>(
          'reader-list-$comicId-$epId-${runtimeState.readerSpreadSize}',
        ),
        padding: EdgeInsets.zero,
        cacheExtent: imagePipelineController.readerListCacheExtent(context),
        itemCount: runtimeState.readerSpreadCount,
        controller: scrollController,
        physics: runtimeState.zoomGestureActive
            ? const NeverScrollableScrollPhysics()
            : const ReaderScrollPhysics(),
        itemBuilder: (context, index) => _buildReaderListItem(index),
      ),
    );
  }

  Widget _buildReaderPageImage(int imageIndex) {
    final url = runtimeState.images[imageIndex];
    final cachedProvider = imagePipelineController.cachedProviderFor(url);
    final readerSurfaceColor = _resolveReaderSurfaceColor(context);
    final readerPlaceholderColor = _resolveReaderPlaceholderColor(context);

    if (noImageModeEnabled) {
      return const SizedBox.expand();
    }

    Widget buildImage(ImageProvider provider) {
      return wrapImageWidget(
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
      future: imagePipelineController.getImageProvider(url),
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
    final imageIndices = runtimeState.spreadImageIndices(spreadIndex);
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

  Widget buildReaderPageView() {
    return PageView.builder(
      key: PageStorageKey<String>(
        'reader-page-$comicId-$epId-rtl-${runtimeState.readerSpreadSize}',
      ),
      controller: pageController,
      reverse: false,
      allowImplicitScrolling: true,
      itemCount: runtimeState.readerSpreadCount,
      physics: runtimeState.pageNavigationLocked
          ? const NeverScrollableScrollPhysics()
          : const PageScrollPhysics(),
      onPageChanged: navigationController.handlePageChanged,
      itemBuilder: (context, index) {
        return _buildReaderPageSpread(index);
      },
    );
  }

  Widget buildTopToBottomReaderView() {
    if (!runtimeState.pinchToZoom ||
        runtimeState.readerMode != ReaderMode.topToBottom) {
      return _buildReaderListView();
    }
    return _buildZoomableReader(child: _buildReaderListView());
  }

  Widget wrapReaderTapPaging(Widget child) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapUp: (details) {
            unawaited(
              navigationController.handleTapUp(details, constraints.maxWidth),
            );
          },
          child: child,
        );
      },
    );
  }

  Widget _buildReaderListItem(int spreadIndex) {
    final imageIndices = runtimeState.spreadImageIndices(spreadIndex);
    if (imageIndices.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      key: spreadIndex < runtimeState.itemKeys.length
          ? runtimeState.itemKeys[spreadIndex]
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
    final url = runtimeState.images[imageIndex];
    final cachedProvider = imagePipelineController.cachedProviderFor(url);
    final readerSurfaceColor = _resolveReaderSurfaceColor(context);
    final readerPlaceholderColor = _resolveReaderPlaceholderColor(context);

    double? currentResolvedAspectRatio() {
      return imagePipelineState.imageAspectRatioCache[url];
    }

    double currentPlaceholderAspectRatio() {
      return currentResolvedAspectRatio() ??
          imagePipelineController.resolvePlaceholderAspectRatio(imageIndex);
    }

    if (noImageModeEnabled) {
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
      return wrapImageWidget(stableImage, url);
    }

    if (cachedProvider != null) {
      return buildImage(cachedProvider);
    }

    return FutureBuilder<ImageProvider>(
      key: ValueKey(url),
      future: imagePipelineController.getImageProvider(url),
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
    final isRetrying = imagePipelineController.isRetrying(url);
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
                            unawaited(imagePipelineController.retryImage(url)),
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

class ReaderScrollPhysics extends ClampingScrollPhysics {
  const ReaderScrollPhysics({super.parent});

  @override
  ReaderScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return ReaderScrollPhysics(parent: buildParent(ancestor));
  }
}
