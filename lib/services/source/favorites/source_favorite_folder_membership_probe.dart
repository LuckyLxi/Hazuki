import '../../../models/hazuki_models.dart';
import 'source_favorites_response_parser.dart';

typedef FavoriteFolderPageLoader =
    Future<SourceFavoriteComicsPage> Function({
      required int page,
      required String folderId,
    });

/// Infers a comic's folder memberships by probing source favorite pages.
class SourceFavoriteFolderMembershipProbe {
  const SourceFavoriteFolderMembershipProbe({int maxProbePages = 120})
    : assert(maxProbePages > 0),
      _maxProbePages = maxProbePages;

  final int _maxProbePages;

  Future<Set<String>> infer({
    required String comicId,
    required List<FavoriteFolder> folders,
    required bool singleFolderOnly,
    required FavoriteFolderPageLoader loadPage,
  }) async {
    final normalizedComicId = comicId.trim();
    if (normalizedComicId.isEmpty) return const <String>{};

    final inferred = <String>{};
    for (final folder in folders) {
      final folderId = folder.id.trim();
      if (folderId.isEmpty || folderId == '0') continue;
      final containsComic = await _containsComic(
        comicId: normalizedComicId,
        folderId: folderId,
        loadPage: loadPage,
      );
      if (!containsComic) continue;
      inferred.add(folderId);
      if (singleFolderOnly) break;
    }
    return inferred;
  }

  Future<bool> _containsComic({
    required String comicId,
    required String folderId,
    required FavoriteFolderPageLoader loadPage,
  }) async {
    var page = 1;
    while (page <= _maxProbePages) {
      final result = await loadPage(page: page, folderId: folderId);
      if (result.comics.isEmpty) return false;
      if (result.comics.any((comic) => comic.id == comicId)) return true;
      if (result.maxPage == null || page >= result.maxPage!) return false;
      page++;
    }
    return false;
  }
}
