part of '../hazuki_source_service.dart';

extension HazukiSourceServiceComicDetailsCacheSupport on HazukiSourceService {
  Future<Directory> _ensureComicDetailsCacheDir() async {
    final existed = _comicDetailsCacheDir;
    if (existed != null) {
      return existed;
    }
    final supportDir = await getApplicationSupportDirectory();
    final dir = Directory('${supportDir.path}/comic_details_cache');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _comicDetailsCacheDir = dir;
    return dir;
  }

  String _comicDetailsCacheFileName(String comicId) {
    final hash = md5.convert(utf8.encode(comicId)).toString();
    return '$hash.json';
  }

  Future<File> _comicDetailsCacheFile(String comicId) async {
    final dir = await _ensureComicDetailsCacheDir();
    return File('${dir.path}/${_comicDetailsCacheFileName(comicId)}');
  }

  ComicDetailsData? _getComicDetailsFromMemoryCache(String comicId) {
    final value = _comicDetailsMemoryCache.remove(comicId);
    if (value == null) {
      return null;
    }
    _comicDetailsMemoryCache[comicId] = value;
    return value;
  }

  void _putComicDetailsInMemoryCache(String comicId, ComicDetailsData details) {
    _comicDetailsMemoryCache.remove(comicId);
    _comicDetailsMemoryCache[comicId] = details;
    while (_comicDetailsMemoryCache.length > 120) {
      _comicDetailsMemoryCache.remove(_comicDetailsMemoryCache.keys.first);
    }
  }

  Map<String, dynamic> _comicDetailsToJson(ComicDetailsData details) {
    return {
      'id': details.id,
      'title': details.title,
      'subTitle': details.subTitle,
      'cover': details.cover,
      'description': details.description,
      'updateTime': details.updateTime,
      'likesCount': details.likesCount,
      'chapters': details.chapters,
      'tags': details.tags,
      'recommend': details.recommend
          .map(
            (comic) => {
              'id': comic.id,
              'title': comic.title,
              'subTitle': comic.subTitle,
              'cover': comic.cover,
            },
          )
          .toList(),
      'isFavorite': details.isFavorite,
      'subId': details.subId,
    };
  }

  ComicDetailsData? _comicDetailsFromJson(Map<String, dynamic> map) {
    final id = map['id']?.toString().trim() ?? '';
    if (id.isEmpty) {
      return null;
    }

    final chapters = <String, String>{};
    final chapterRaw = map['chapters'];
    if (chapterRaw is Map) {
      for (final entry in chapterRaw.entries) {
        final key = entry.key.toString().trim();
        final value = entry.value?.toString().trim() ?? '';
        if (key.isNotEmpty && value.isNotEmpty) {
          chapters[key] = value;
        }
      }
    }

    final tags = <String, List<String>>{};
    final tagsRaw = map['tags'];
    if (tagsRaw is Map) {
      for (final entry in tagsRaw.entries) {
        final value = entry.value;
        if (value is List) {
          tags[entry.key.toString()] = value.map((e) => e.toString()).toList();
        }
      }
    }

    final recommend = <ExploreComic>[];
    final recommendRaw = map['recommend'];
    if (recommendRaw is List) {
      for (final item in recommendRaw) {
        if (item is! Map) {
          continue;
        }
        final recommendMap = Map<String, dynamic>.from(item);
        final rid = recommendMap['id']?.toString().trim() ?? '';
        final title = recommendMap['title']?.toString().trim() ?? '';
        if (rid.isEmpty || title.isEmpty) {
          continue;
        }
        recommend.add(
          ExploreComic(
            id: rid,
            title: title,
            subTitle:
                (recommendMap['subTitle'] ?? recommendMap['subtitle'] ?? '')
                    .toString()
                    .trim(),
            cover: recommendMap['cover']?.toString().trim() ?? '',
          ),
        );
      }
    }

    return ComicDetailsData(
      id: id,
      title: map['title']?.toString() ?? '',
      subTitle: map['subTitle']?.toString() ?? '',
      cover: map['cover']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      updateTime: map['updateTime']?.toString() ?? '',
      likesCount: map['likesCount']?.toString() ?? '',
      chapters: chapters,
      tags: tags,
      recommend: recommend,
      isFavorite: _asBool(map['isFavorite']),
      subId: map['subId']?.toString() ?? '',
    );
  }

  // ignore: unused_element
  Future<ComicDetailsData?> _readComicDetailsFromDisk(String comicId) async {
    try {
      final file = await _comicDetailsCacheFile(comicId);
      if (!await file.exists()) {
        return null;
      }
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) {
        return null;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }
      final now = DateTime.now();
      await file.setLastAccessed(now);
      await file.setLastModified(now);
      return _comicDetailsFromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }

  // ignore: unused_element
  Future<void> _saveComicDetailsToDisk(
    String comicId,
    ComicDetailsData details,
  ) async {
    try {
      final file = await _comicDetailsCacheFile(comicId);
      await file.writeAsString(
        jsonEncode(_comicDetailsToJson(details)),
        flush: false,
      );
    } catch (_) {}
  }
}
