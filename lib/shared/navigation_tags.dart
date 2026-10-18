import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import '../models/hazuki_models.dart';
import '../widgets/cached_image_widgets.dart';
import '../widgets/source_image_gateway_scope.dart';
import 'ui_flags.dart';
import 'images/comic_cover_handoff.dart';

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
      : (imageGateway.activeSourceKey ?? '');
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
  final hero = context.widget;
  if (hero is Hero) {
    final child = _heroContent(hero.child);
    if (child is ComicCoverHeroImage) return child.image;
  }
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

Widget _heroContent(Widget child) =>
    child is KeyedSubtree ? child.child : child;

/// Keeps the image state alive across both Hero placeholders. Flutter's own
/// placeholder key is absent when a custom placeholder is used, so the content
/// needs its own key to avoid restarting downloads and image reveals.
class ComicCoverHero extends StatefulWidget {
  const ComicCoverHero({
    super.key,
    required this.tag,
    required this.image,
    required this.child,
  });

  final Object tag;
  final HazukiCachedImage? image;
  final Widget child;

  @override
  State<ComicCoverHero> createState() => _ComicCoverHeroState();
}

class _ComicCoverHeroState extends State<ComicCoverHero> {
  final GlobalKey _contentKey = GlobalKey();

  @override
  Widget build(BuildContext context) => Hero(
    tag: widget.tag,
    flightShuttleBuilder: buildComicCoverHeroFlightShuttle,
    placeholderBuilder: buildComicCoverHeroPlaceholder,
    child: KeyedSubtree(
      key: _contentKey,
      child: ComicCoverHeroImage(image: widget.image, child: widget.child),
    ),
  );
}

/// Exposes an image's provider parameters without traversing elements during a
/// Hero overlay build, when Flutter locks child-element traversal in debug mode.
class ComicCoverHeroImage extends StatelessWidget {
  const ComicCoverHeroImage({
    super.key,
    required this.image,
    required this.child,
  });

  final HazukiCachedImage? image;
  final Widget child;

  @override
  Widget build(BuildContext context) => child;
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
  final handoff = ComicCoverHandoffScope.find(fromHeroContext, heroTag);
  final destinationHandoff = ComicCoverHandoffScope.find(
    toHeroContext,
    heroTag,
  );
  if (flightDirection == HeroFlightDirection.push &&
      destinationHandoff?.hasDecodedBanner == true &&
      !hazukiNoImageModeNotifier.value) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox.expand(child: destinationHandoff!.buildBanner()),
    );
  }
  if (flightDirection == HeroFlightDirection.pop &&
      handoff != null &&
      !handoff.coverRevealed &&
      !hazukiNoImageModeNotifier.value) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox.expand(child: handoff.buildBanner()),
    );
  }

  // 从 from 端的 widget tree 中提取 HazukiCachedImage 的实际参数
  final cachedImage = _findCachedImageInSubtree(fromHeroContext);
  if (cachedImage != null) {
    final url = cachedImage.url.trim();
    if (url.isNotEmpty) {
      final sourceKey = cachedImage.sourceKey.trim().isNotEmpty
          ? cachedImage.sourceKey
          : ((cachedImage.imageGateway ?? scopedImageGateway).activeSourceKey ??
                '');
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
        if (destinationCachedImage != null &&
            destinationCachedImage.url.trim() == url) {
          _precacheHeroDestinationImage(
            flightContext,
            bytes,
            destinationCachedImage,
          );
        }
        Widget flightImage = Image.memory(
          bytes,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
          // 使用和 from 端完全相同的 resize 参数，确保 ImageProvider 一致
          cacheWidth: cachedImage.cacheWidth,
          cacheHeight: cachedImage.cacheHeight,
        );
        // Returning from a resolved cover to promotional art needs the inverse
        // handoff. The banner is already decoded on the underlying carousel.
        if (flightDirection == HeroFlightDirection.pop &&
            handoff != null &&
            destinationCachedImage != null &&
            destinationCachedImage.url.trim() != url) {
          final destinationUrl = destinationCachedImage.url.trim();
          final destinationSourceKey =
              destinationCachedImage.sourceKey.trim().isEmpty
              ? handoff.sourceKey
              : destinationCachedImage.sourceKey;
          final destinationBytes =
              destinationUrl == handoff.url &&
                  destinationSourceKey == handoff.sourceKey
              ? handoff.bytes
              : peekHazukiWidgetImageMemory(
                      destinationUrl,
                      sourceKey: destinationSourceKey,
                    ) ??
                    (destinationCachedImage.imageGateway ?? scopedImageGateway)
                        .peekImageBytesFromMemory(
                          destinationUrl,
                          sourceKey: destinationSourceKey,
                        );
          final sourceImage = flightImage;
          final returnAnimation =
              ModalRoute.of(fromHeroContext)?.animation ?? animation;
          Widget blendBanner(Widget banner) => Stack(
            fit: StackFit.expand,
            children: [
              sourceImage,
              AnimatedBuilder(
                animation: returnAnimation,
                child: banner,
                builder: (_, child) => Opacity(
                  opacity: Curves.easeOutCubic.transform(
                    ((0.45 - returnAnimation.value) / 0.45).clamp(0.0, 1.0),
                  ),
                  child: child,
                ),
              ),
            ],
          );
          if (destinationUrl == handoff.url &&
              destinationSourceKey == handoff.sourceKey &&
              handoff.hasDecodedBanner) {
            flightImage = blendBanner(handoff.buildBanner());
          } else if (destinationBytes != null) {
            flightImage = Image.memory(
              destinationBytes,
              fit: BoxFit.cover,
              cacheWidth: destinationCachedImage.cacheWidth,
              cacheHeight: destinationCachedImage.cacheHeight,
              gaplessPlayback: true,
              filterQuality: FilterQuality.medium,
              errorBuilder: (_, _, _) => sourceImage,
              frameBuilder: (context, banner, frame, _) =>
                  frame == null ? sourceImage : blendBanner(banner),
            );
          }
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: SizedBox.expand(child: flightImage),
        );
      }
    }
  }

  // fallback：bytes 不可用时使用 fromHero.child，但保持和 bytes 路径一致的裁剪。
  return ClipRRect(
    borderRadius: BorderRadius.circular(borderRadius),
    child: SizedBox.expand(
      child: handoff == null
          ? _heroContent(fromHero.child)
          : ComicCoverHandoffScope(
              handoff: handoff,
              child: _heroContent(fromHero.child),
            ),
    ),
  );
}
