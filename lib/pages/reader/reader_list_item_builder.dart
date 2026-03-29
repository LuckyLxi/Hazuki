part of '../reader_page.dart';

extension _ReaderListItemBuilderExtension on _ReaderPageState {
  Widget _buildReaderListItem(int index) {
    final url = _images[index];
    final cachedProvider = _providerCache[url];
    final resolvedAspectRatio = _imageAspectRatioCache[url];
    final placeholderAspectRatio =
        resolvedAspectRatio ?? _resolvePlaceholderAspectRatio(index);
    final readerPlaceholderColor = Theme.of(context).scaffoldBackgroundColor;

    if (_noImageModeEnabled) {
      return AspectRatio(
        key: index < _itemKeys.length ? _itemKeys[index] : null,
        aspectRatio: 3 / 4,
        child: const SizedBox.expand(),
      );
    }

    Widget buildImage(ImageProvider provider) {
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
          return ColoredBox(color: readerPlaceholderColor);
        },
        errorBuilder: (_, _, _) {
          return Container(
            height: 120,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            alignment: Alignment.center,
            child: const Icon(Icons.broken_image_outlined),
          );
        },
      );
      final stableImage = resolvedAspectRatio == null
          ? image
          : ColoredBox(
              color: readerPlaceholderColor,
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
              aspectRatio: placeholderAspectRatio,
              child: Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                alignment: Alignment.center,
                child: const Icon(Icons.broken_image_outlined),
              ),
            );
          }
          return AspectRatio(
            aspectRatio: placeholderAspectRatio,
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
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
