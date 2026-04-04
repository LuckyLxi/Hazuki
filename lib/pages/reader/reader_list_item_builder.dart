part of '../reader_page.dart';

extension _ReaderListItemBuilderExtension on _ReaderPageState {
  Widget _buildReaderListItem(int index) {
    final url = _images[index];
    final cachedProvider = _providerCache[url];
    final readerSurfaceColor = _resolveReaderSurfaceColor(context);
    final readerPlaceholderColor = _resolveReaderPlaceholderColor(context);

    double? currentResolvedAspectRatio() => _imageAspectRatioCache[url];

    double currentPlaceholderAspectRatio() {
      return currentResolvedAspectRatio() ??
          _resolvePlaceholderAspectRatio(index);
    }

    if (_noImageModeEnabled) {
      return AspectRatio(
        key: index < _itemKeys.length ? _itemKeys[index] : null,
        aspectRatio: 3 / 4,
        child: const SizedBox.expand(),
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
          return ColoredBox(
            color: readerPlaceholderColor,
            child: const SizedBox(
              height: 120,
              child: Center(child: Icon(Icons.broken_image_outlined)),
            ),
          );
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

    Widget content;
    if (cachedProvider != null) {
      content = buildImage(cachedProvider);
    } else {
      content = FutureBuilder<ImageProvider>(
        key: ValueKey(url),
        future: _getOrCreateImageProviderFuture(url),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return buildImage(snapshot.data!);
          }
          if (snapshot.hasError) {
            return AspectRatio(
              aspectRatio: currentPlaceholderAspectRatio(),
              child: ColoredBox(
                color: readerPlaceholderColor,
                child: const Center(child: Icon(Icons.broken_image_outlined)),
              ),
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

    return Container(
      key: index < _itemKeys.length ? _itemKeys[index] : null,
      child: content,
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
