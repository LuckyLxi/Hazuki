import '../../models/hazuki_models.dart';

const legacyLocalFavoriteSourceKey = 'jm';

class LocalFavoritesSnapshot {
  LocalFavoritesSnapshot({required this.folders, required this.entries});

  final List<LocalFavoriteFolderRecord> folders;
  final List<LocalFavoriteComicRecord> entries;

  LocalFavoriteComicRecord? findEntry(String comicId, {String sourceKey = ''}) {
    for (final entry in entries) {
      final requested = sourceKey.trim();
      final storedSourceKey = entry.sourceKey.trim().isEmpty
          ? legacyLocalFavoriteSourceKey
          : entry.sourceKey.trim();
      if (entry.comicId == comicId &&
          (requested.isEmpty || storedSourceKey == requested)) {
        return entry;
      }
    }
    return null;
  }
}

class LocalFavoriteFolderRecord {
  LocalFavoriteFolderRecord({
    required this.id,
    required this.name,
    required this.sourceKey,
    required this.updatedAtMs,
  });

  factory LocalFavoriteFolderRecord.fromJson(Map<String, dynamic> json) {
    return LocalFavoriteFolderRecord(
      id: (json['id'] ?? '').toString().trim(),
      name: (json['name'] ?? '').toString().trim(),
      sourceKey: (json['sourceKey'] ?? '').toString().trim(),
      updatedAtMs: (json['updatedAtMs'] as num?)?.toInt() ?? 0,
    );
  }

  final String id;
  final String name;
  final String sourceKey;
  final int updatedAtMs;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    if (sourceKey.isNotEmpty) 'sourceKey': sourceKey,
    'updatedAtMs': updatedAtMs,
  };
}

class LocalFavoriteComicRecord {
  LocalFavoriteComicRecord({
    required this.comicId,
    required this.sourceKey,
    required this.title,
    required this.subTitle,
    required this.cover,
    required this.updateTime,
    List<String> tags = const [],
    required Map<String, int> folderSavedAtMs,
  }) : tags = List<String>.from(tags),
       folderSavedAtMs = Map<String, int>.from(folderSavedAtMs);

  factory LocalFavoriteComicRecord.fromJson(Map<String, dynamic> json) {
    final folderSavedAtMs = <String, int>{};
    final folderSavedAtMsRaw = json['folderSavedAtMs'];
    if (folderSavedAtMsRaw is Map) {
      for (final entry in folderSavedAtMsRaw.entries) {
        final id = entry.key?.toString().trim() ?? '';
        if (id.isNotEmpty) {
          folderSavedAtMs[id] =
              (entry.value as num?)?.toInt() ??
              DateTime.now().millisecondsSinceEpoch;
        }
      }
    }

    // Migrate the legacy folderIds + savedAtMs representation in memory.
    if (folderSavedAtMs.isEmpty) {
      final fallbackMs =
          (json['savedAtMs'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch;
      final folderIdsRaw = json['folderIds'];
      if (folderIdsRaw is List) {
        for (final item in folderIdsRaw) {
          final id = item?.toString().trim() ?? '';
          if (id.isNotEmpty) {
            folderSavedAtMs[id] = fallbackMs;
          }
        }
      }
    }

    return LocalFavoriteComicRecord(
      comicId: (json['comicId'] ?? '').toString().trim(),
      sourceKey: (json['sourceKey'] ?? '').toString().trim(),
      title: (json['title'] ?? '').toString(),
      subTitle: (json['subTitle'] ?? '').toString(),
      cover: (json['cover'] ?? '').toString(),
      updateTime: (json['updateTime'] ?? '').toString(),
      tags: _tagsFromJson(json['tags']),
      folderSavedAtMs: folderSavedAtMs,
    );
  }

  final String comicId;
  final String sourceKey;
  String title;
  String subTitle;
  String cover;
  String updateTime;
  List<String> tags;
  final Map<String, int> folderSavedAtMs;

  int get savedAtMs {
    var latest = 0;
    for (final savedAtMs in folderSavedAtMs.values) {
      if (savedAtMs > latest) {
        latest = savedAtMs;
      }
    }
    return latest;
  }

  Set<String> get folderIds => folderSavedAtMs.keys.toSet();

  ExploreComic toExploreComic({String sourceKey = ''}) {
    final resolvedSourceKey = this.sourceKey.trim().isNotEmpty
        ? this.sourceKey
        : sourceKey.trim();
    return ExploreComic(
      id: comicId,
      title: title,
      subTitle: subTitle,
      cover: cover,
      sourceKey: resolvedSourceKey,
      tags: tags,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'comicId': comicId,
    if (sourceKey.isNotEmpty) 'sourceKey': sourceKey,
    'title': title,
    'subTitle': subTitle,
    'cover': cover,
    'updateTime': updateTime,
    'tags': tags,
    'savedAtMs': savedAtMs,
    'folderIds': folderIds.toList(growable: false),
    'folderSavedAtMs': folderSavedAtMs,
  };
}

List<String> _tagsFromJson(Object? value) => value is List
    ? value
          .map((tag) => tag.toString().trim())
          .where((tag) => tag.isNotEmpty)
          .toSet()
          .toList(growable: false)
    : const [];

class LocalFavoriteFolderTombstone {
  const LocalFavoriteFolderTombstone(this.folderId, this.deletedAtMs);

  final String folderId;
  final int deletedAtMs;
}

class LocalFavoriteEntryTombstone {
  const LocalFavoriteEntryTombstone({
    required this.comicId,
    required this.sourceKey,
    required this.deletedAtMs,
  });

  final String comicId;
  final String sourceKey;
  final int deletedAtMs;
}

class LocalFavoriteComicFolderTombstone {
  const LocalFavoriteComicFolderTombstone({
    required this.comicId,
    required this.sourceKey,
    required this.folderId,
    required this.deletedAtMs,
  });

  final String comicId;
  final String sourceKey;
  final String folderId;
  final int deletedAtMs;
}
