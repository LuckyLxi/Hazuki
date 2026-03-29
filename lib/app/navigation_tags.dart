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
