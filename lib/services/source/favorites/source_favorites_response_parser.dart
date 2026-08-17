import '../../../models/hazuki_models.dart';

typedef FavoriteExploreComicsParser =
    List<ExploreComic> Function(List comics, {String sourceKey});

class SourceFavoriteComicsPage {
  const SourceFavoriteComicsPage({required this.comics, this.maxPage});

  final List<ExploreComic> comics;
  final int? maxPage;
}

class SourceFavoriteFoldersData {
  const SourceFavoriteFoldersData({
    required this.folders,
    required this.favoritedFolderIds,
  });

  final List<FavoriteFolder> folders;
  final Set<String> favoritedFolderIds;
}

/// Adapts source favorite payloads into stable domain values.
class SourceFavoritesResponseParser {
  const SourceFavoritesResponseParser(this._parseExploreComics);

  final FavoriteExploreComicsParser _parseExploreComics;

  static String normalizeFolderId(String folderId) =>
      folderId.trim().isEmpty ? '0' : folderId.trim();

  static List<ExploreComic> mergeComics(Iterable<ExploreComic> comics) {
    final merged = <String, ExploreComic>{};
    for (final comic in comics) {
      if (comic.id.isNotEmpty) merged[comic.id] = comic;
    }
    return merged.values.toList();
  }

  List<ExploreComic> parseComics(List comics, {String sourceKey = ''}) =>
      _parseExploreComics(comics, sourceKey: sourceKey);

  SourceFavoriteComicsPage parseComicsPage(
    dynamic response, {
    String sourceKey = '',
  }) {
    if (response is! Map) {
      return const SourceFavoriteComicsPage(comics: []);
    }
    final map = Map<String, dynamic>.from(response);
    final rawComics = map['comics'];
    return SourceFavoriteComicsPage(
      comics: rawComics is List
          ? _parseExploreComics(rawComics, sourceKey: sourceKey)
          : const [],
      maxPage: parseMaxPage(map['maxPage']),
    );
  }

  SourceFavoriteFoldersData parseFolders(Map<dynamic, dynamic> response) {
    final map = Map<String, dynamic>.from(response);
    final folders = <FavoriteFolder>[];
    final rawFolders = map['folders'];
    if (rawFolders is Map) {
      for (final entry in Map<String, dynamic>.from(rawFolders).entries) {
        final id = entry.key.toString();
        if (id.isNotEmpty) {
          folders.add(
            FavoriteFolder(id: id, name: entry.value?.toString() ?? id),
          );
        }
      }
    }
    if (!folders.any((folder) => folder.id == '0')) {
      folders.insert(
        0,
        const FavoriteFolder(id: '0', name: '__favorite_all__'),
      );
    }

    final favorited = <String>{};
    final rawFavorited = map['favorited'];
    if (rawFavorited is List) {
      for (final item in rawFavorited) {
        final id = item?.toString() ?? '';
        if (id.isNotEmpty) favorited.add(id);
      }
    }
    favorited.removeWhere((id) => !folders.any((folder) => folder.id == id));
    return SourceFavoriteFoldersData(
      folders: folders,
      favoritedFolderIds: favorited,
    );
  }

  List<String> extractFolderIds(dynamic response) {
    if (response is! Map) return const [];
    final rawFolders = Map<String, dynamic>.from(response)['folders'];
    if (rawFolders is! Map) return const [];
    final ids = <String>[];
    for (final entry in rawFolders.entries) {
      final id = entry.key.toString().trim();
      if (id.isNotEmpty && id != '0') ids.add(id);
    }
    return ids;
  }

  static int? parseMaxPage(dynamic value) => switch (value) {
    int page => page,
    num page => page.toInt(),
    _ => int.tryParse(value?.toString() ?? ''),
  };
}
