import 'package:flutter/widgets.dart';

import '../models/hazuki_models.dart';

typedef ComicHeroTagBuilder =
    String Function(ExploreComic comic, {String? salt});
typedef ComicDetailPageBuilder =
    Widget Function(ExploreComic comic, String heroTag);

const discoverSearchHeroTag = 'discover_search_to_search_page';

String comicCoverHeroTag(ExploreComic comic, {String? salt}) {
  final key = comic.id.isEmpty ? comic.title : comic.id;
  if (salt == null || salt.isEmpty) {
    return 'comic-cover-$key';
  }
  return 'comic-cover-$key-$salt';
}

/// 漫画封面 Hero 飞行动画构建器（cross-fade 淡入淡出）
///
/// 必须在 source 和 destination 两端的 Hero 上都设置此 builder，
/// 否则返回时仍会出现突然缩回原始尺寸的闪烁 bug。
Widget buildComicCoverHeroFlightShuttle(
  BuildContext flightContext,
  Animation<double> animation,
  HeroFlightDirection flightDirection,
  BuildContext fromHeroContext,
  BuildContext toHeroContext,
) {
  final fromHero = fromHeroContext.widget as Hero;
  final toHero = toHeroContext.widget as Hero;
  return Stack(
    fit: StackFit.expand,
    children: [
      FadeTransition(
        opacity: ReverseAnimation(animation),
        child: fromHero.child,
      ),
      FadeTransition(opacity: animation, child: toHero.child),
    ],
  );
}
