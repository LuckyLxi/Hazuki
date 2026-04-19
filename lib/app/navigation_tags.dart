import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import '../models/hazuki_models.dart';
import '../widgets/cached_image_widgets.dart';

typedef ComicHeroTagBuilder =
    String Function(ExploreComic comic, {String? salt});
typedef ComicDetailPageBuilder =
    Widget Function(ExploreComic comic, String heroTag);

const discoverSearchHeroTag = 'discover_search_to_search_page';

final Map<String, String> _heroTagToImageUrl = {};

void registerComicCoverHeroUrl(String heroTag, String url) {
  final normalized = url.trim();
  if (normalized.isNotEmpty) {
    _heroTagToImageUrl[heroTag] = normalized;
  }
}

String comicCoverHeroTag(ExploreComic comic, {String? salt}) {
  final key = comic.id.isEmpty ? comic.title : comic.id;
  if (salt == null || salt.isEmpty) {
    return 'comic-cover-$key';
  }
  return 'comic-cover-$key-$salt';
}

double comicCoverHeroBorderRadius(String heroTag, {double fallback = 10}) {
  if (heroTag.contains('discover-daily-')) {
    return 28;
  }
  return fallback;
}

Widget buildComicCoverHeroPlaceholder(
  BuildContext context,
  Size heroSize,
  Widget child,
) {
  return SizedBox(width: heroSize.width, height: heroSize.height);
}

/// 漫画封面 Hero 飞行动画构建器
///
/// 必须在 source 和 destination 两端的 Hero 上都设置此 builder，
/// 否则返回时仍会出现突然缩回原始尺寸的闪烁 bug。
///
/// 用注册的图片 bytes 直接渲染 BoxFit.cover，避免 Hero child 尺寸约束或
/// OverflowBox/Transform 导致的图片不填充 shuttle / 落地突变问题。
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

  final url = _heroTagToImageUrl[heroTag];
  Uint8List? bytes;
  if (url != null) {
    bytes = peekHazukiWidgetImageMemory(url);
  }

  final child = flightDirection == HeroFlightDirection.push
      ? toHero.child
      : fromHero.child;

  return ClipRRect(
    borderRadius: BorderRadius.circular(borderRadius),
    child: bytes != null
        ? SizedBox.expand(
            child: Image.memory(
              bytes,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              filterQuality: FilterQuality.medium,
            ),
          )
        : child,
  );
}
