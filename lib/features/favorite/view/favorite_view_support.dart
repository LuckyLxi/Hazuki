import 'package:hazuki/models/hazuki_models.dart';

enum FavoriteEntryAnimationStyle { none, staggered }

String favoriteComicHeroTag(ExploreComic comic, {String? salt}) {
  final key = comic.id.isEmpty ? comic.title : comic.id;
  if (salt == null || salt.isEmpty) {
    return 'comic-cover-$key';
  }
  return 'comic-cover-$key-$salt';
}
