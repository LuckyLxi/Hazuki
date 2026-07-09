import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import '../models/hazuki_models.dart';
import '../widgets/cached_image_widgets.dart';
import '../widgets/source_image_gateway_scope.dart';
import 'ui_flags.dart';

typedef ComicHeroTagBuilder =
    String Function(ExploreComic comic, {String? salt});
typedef ComicDetailPageBuilder =
    Widget Function(ExploreComic comic, String heroTag);

const discoverSearchHeroTag = 'discover_search_to_search_page';
const homeProfileAvatarHeroTag = 'home_profile_avatar_to_drawer';
const discoverDailyHeroSaltPrefix = 'discover-daily-';

String comicCoverHeroTag(ExploreComic comic, {String? salt}) {
  final key = comic.id.isEmpty ? comic.title : comic.scopedId.storageKey;
  if (salt == null || salt.isEmpty) {
    return 'comic-cover-$key';
  }
  return 'comic-cover-$key-$salt';
}

double comicCoverHeroBorderRadius(String heroTag, {double fallback = 10}) {
  if (heroTag.contains(discoverDailyHeroSaltPrefix)) {
    return 28;
  }
  return fallback;
}

Future<void> precacheComicCoverHeroImages(
  BuildContext context, {
  required String url,
  required String sourceKey,
  int? sourceCacheWidth,
  int? sourceCacheHeight,
}) async {
  final normalized = url.trim();
  if (normalized.isEmpty || hazukiNoImageModeNotifier.value) {
    return;
  }
  final imageGateway = SourceImageGatewayScope.of(context);
  final resolvedSourceKey = sourceKey.trim().isNotEmpty
      ? sourceKey.trim()
      : imageGateway.activeSourceKey;
  try {
    var bytes =
        peekHazukiWidgetImageMemory(normalized, sourceKey: resolvedSourceKey) ??
        imageGateway.peekImageBytesFromMemory(
          normalized,
          sourceKey: resolvedSourceKey,
        );
    bytes ??= await imageGateway.downloadImageBytes(
      normalized,
      keepInMemory: true,
      sourceKey: resolvedSourceKey,
    );
    putHazukiWidgetImageMemory(normalized, bytes, sourceKey: resolvedSourceKey);
    if (!context.mounted) {
      return;
    }

    final baseProvider = MemoryImage(bytes);
    await precacheImage(baseProvider, context);
    if (!context.mounted ||
        (sourceCacheWidth == null && sourceCacheHeight == null)) {
      return;
    }
    await precacheImage(
      ResizeImage.resizeIfNeeded(
        sourceCacheWidth,
        sourceCacheHeight,
        baseProvider,
      ),
      context,
    );
  } catch (_) {}
}

Widget buildComicCoverHeroPlaceholder(
  BuildContext context,
  Size heroSize,
  Widget child,
) {
  // 使用 Visibility 隐藏 child 但保持其布局尺寸。
  // 如果用空 SizedBox，Expanded 内的约束变化可能导致列表项布局抖动，
  // 视觉上表现为"闪一下"。maintainSize 确保占位空间与原始 child 完全一致。
  return Visibility(
    visible: false,
    maintainSize: true,
    maintainAnimation: true,
    maintainState: true,
    child: child,
  );
}

/// 从 [BuildContext] 的 element tree 中递归查找 [HazukiCachedImage] widget。
/// 用于在 shuttle builder 中提取 from 端实际使用的 cacheWidth / cacheHeight，
/// 确保 shuttle 的 ImageProvider 与 from 端完全一致，命中 Flutter ImageCache。
HazukiCachedImage? _findCachedImageInSubtree(BuildContext context) {
  HazukiCachedImage? result;
  void visitor(Element element) {
    if (result != null) return;
    if (element.widget is HazukiCachedImage) {
      result = element.widget as HazukiCachedImage;
      return;
    }
    element.visitChildren(visitor);
  }

  try {
    // shuttle builder 在 build 阶段执行，此时 visitChildElements 可能抛出断言，
    // 捕获后返回 null，Hero 动画将 fallback 到 fromHero.child
    context.visitChildElements(visitor);
  } catch (_) {
    return null;
  }
  return result;
}

void _precacheHeroDestinationImage(
  BuildContext context,
  Uint8List bytes,
  HazukiCachedImage cachedImage,
) {
  final provider = ResizeImage.resizeIfNeeded(
    cachedImage.cacheWidth,
    cachedImage.cacheHeight,
    MemoryImage(bytes),
  );
  unawaited(precacheImage(provider, context).catchError((_) {}));
}

/// 漫画封面 Hero 飞行动画构建器
///
/// 从 fromHeroContext 的 widget tree 中提取 [HazukiCachedImage] 的 url、
/// cacheWidth、cacheHeight，构建和 from 端参数完全一致的 Image.memory，
/// 确保 ImageProvider 相同从而命中 Flutter ImageCache，第一帧即渲染。
///
/// Push 时 from = source tile → 用 tile 的 cacheWidth → 命中 tile 的缓存。
/// Pop 时 from = detail header → 用 header 的 cacheWidth/Height → 命中 header 的缓存。
Widget buildComicCoverHeroFlightShuttle(
  BuildContext flightContext,
  Animation<double> animation,
  HeroFlightDirection flightDirection,
  BuildContext fromHeroContext,
  BuildContext toHeroContext,
) {
  final fromHero = fromHeroContext.widget as Hero;
  final toHero = toHeroContext.widget as Hero;
  final heroTag =
      (flightDirection == HeroFlightDirection.push ? toHero.tag : fromHero.tag)
          .toString();
  final borderRadius = comicCoverHeroBorderRadius(heroTag, fallback: 10);
  final scopedImageGateway = SourceImageGatewayScope.of(flightContext);

  // 从 from 端的 widget tree 中提取 HazukiCachedImage 的实际参数
  final cachedImage = _findCachedImageInSubtree(fromHeroContext);
  if (cachedImage != null) {
    final url = cachedImage.url.trim();
    if (url.isNotEmpty) {
      final sourceKey = cachedImage.sourceKey.trim().isNotEmpty
          ? cachedImage.sourceKey
          : (cachedImage.imageGateway ?? scopedImageGateway).activeSourceKey;
      final imageGateway = cachedImage.imageGateway ?? scopedImageGateway;
      var bytes = peekHazukiWidgetImageMemory(url, sourceKey: sourceKey);
      if (bytes == null) {
        bytes = imageGateway.peekImageBytesFromMemory(
          url,
          sourceKey: sourceKey,
        );
        if (bytes != null) {
          putHazukiWidgetImageMemory(url, bytes, sourceKey: sourceKey);
        }
      }
      if (bytes != null) {
        final destinationCachedImage = _findCachedImageInSubtree(toHeroContext);
        if (destinationCachedImage != null) {
          _precacheHeroDestinationImage(
            flightContext,
            bytes,
            destinationCachedImage,
          );
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: SizedBox.expand(
            child: Image.memory(
              bytes,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              filterQuality: FilterQuality.medium,
              // 使用和 from 端完全相同的 resize 参数，确保 ImageProvider 一致
              cacheWidth: cachedImage.cacheWidth,
              cacheHeight: cachedImage.cacheHeight,
            ),
          ),
        );
      }
    }
  }

  // fallback：bytes 不可用时使用 fromHero.child，但保持和 bytes 路径一致的裁剪。
  return ClipRRect(
    borderRadius: BorderRadius.circular(borderRadius),
    child: SizedBox.expand(child: fromHero.child),
  );
}
