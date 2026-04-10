part of '../reader_page.dart';

extension _ReaderListItemBuilderExtension on _ReaderPageState {
  Widget _buildReaderListItem(int spreadIndex) {
    final imageIndices = _spreadImageIndices(spreadIndex);
    if (imageIndices.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      key: spreadIndex < _itemKeys.length ? _itemKeys[spreadIndex] : null,
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
    final url = _images[imageIndex];
    final cachedProvider = _providerCache[url];
    final readerSurfaceColor = _resolveReaderSurfaceColor(context);
    final readerPlaceholderColor = _resolveReaderPlaceholderColor(context);

    double? currentResolvedAspectRatio() => _imageAspectRatioCache[url];

    double currentPlaceholderAspectRatio() {
      return currentResolvedAspectRatio() ??
          _resolvePlaceholderAspectRatio(imageIndex);
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
      future: _getOrCreateImageProviderFuture(url),
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
    final isRetrying = _retryingImageUrls.contains(url);
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
                      : () => unawaited(_retryReaderImage(url)),
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

class _ReaderScrollPhysics extends ClampingScrollPhysics {
  const _ReaderScrollPhysics({super.parent});

  @override
  _ReaderScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _ReaderScrollPhysics(parent: buildParent(ancestor));
  }
}
