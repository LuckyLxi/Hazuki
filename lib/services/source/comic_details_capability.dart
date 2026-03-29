part of '../hazuki_source_service.dart';

extension HazukiSourceServiceComicDetailsCapability on HazukiSourceService {
  Future<ComicDetailsData> loadComicDetails(String comicId) async {
    final normalizedComicId = comicId.trim();
    if (normalizedComicId.isEmpty) {
      throw Exception('comic_id_empty');
    }

    final memoryCached = _getComicDetailsFromMemoryCache(normalizedComicId);
    if (memoryCached != null) {
      return memoryCached;
    }

    final engine = _engine;
    if (engine == null) {
      throw Exception('source_not_initialized');
    }

    final dynamic result = engine.evaluate('''(async () => {
        const data = await this.__hazuki_source.comic.loadInfo(${jsonEncode(normalizedComicId)});
        const chapterEntries = [];
        const chapters = data?.chapters;
        if (chapters?.entries && typeof chapters.entries === 'function') {
          for (const pair of chapters.entries()) {
            if (Array.isArray(pair) && pair.length >= 2) {
              chapterEntries.push([String(pair[0] ?? ''), String(pair[1] ?? '')]);
            }
          }
        } else if (Array.isArray(chapters)) {
          for (const item of chapters) {
            if (Array.isArray(item) && item.length >= 2) {
              chapterEntries.push([String(item[0] ?? ''), String(item[1] ?? '')]);
            } else if (item && typeof item === 'object') {
              chapterEntries.push([
                String(item.id ?? item.epId ?? item.key ?? ''),
                String(item.title ?? item.name ?? item.value ?? ''),
              ]);
            }
          }
        } else if (chapters && typeof chapters === 'object') {
          for (const key of Object.keys(chapters)) {
            chapterEntries.push([String(key), String(chapters[key] ?? '')]);
          }
        }
        return {
          ...data,
          __chapterEntries: chapterEntries,
        };
      })()''', name: 'source_comic_detail.js');
    final dynamic resolved = result is Future ? await result : result;
    if (resolved is! Map) {
      throw Exception('comic_details_invalid_response');
    }

    final details = _buildComicDetailsFromSourceMap(
      map: Map<String, dynamic>.from(resolved),
      normalizedComicId: normalizedComicId,
    );

    _putComicDetailsInMemoryCache(normalizedComicId, details);
    if (details.id != normalizedComicId) {
      _putComicDetailsInMemoryCache(details.id, details);
    }
    return details;
  }

  Future<List<String>> loadChapterImages({
    required String comicId,
    required String epId,
  }) async {
    final engine = _engine;
    if (engine == null) {
      throw Exception('漫画源尚未初始化完成');
    }

    final dynamic result = engine.evaluate(
      'this.__hazuki_source.comic.loadEp(${jsonEncode(comicId)}, ${jsonEncode(epId)})',
      name: 'source_chapter_images.js',
    );
    final dynamic resolved = result is Future ? await result : result;
    if (resolved is! Map) {
      return const [];
    }

    final imagesRaw = Map<String, dynamic>.from(resolved)['images'];
    if (imagesRaw is! List) {
      return const [];
    }

    return imagesRaw
        .map((e) => e.toString())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  ComicDetailsData _buildComicDetailsFromSourceMap({
    required Map<String, dynamic> map,
    required String normalizedComicId,
  }) {
    final chapters = _extractComicDetailsChapters(
      map,
      fallbackComicId: normalizedComicId,
    );
    final recommend = _extractComicDetailsRecommendations(map);

    final detailsComicId = map['id']?.toString().trim() ?? '';
    final finalComicId = detailsComicId.isEmpty
        ? normalizedComicId
        : detailsComicId;

    return ComicDetailsData(
      id: finalComicId,
      title: map['title']?.toString() ?? '',
      subTitle: (map['subTitle'] ?? map['subtitle'] ?? '').toString(),
      cover: map['cover']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      updateTime: map['updateTime']?.toString() ?? '',
      likesCount: map['likesCount']?.toString() ?? '',
      chapters: chapters,
      tags: _extractComicDetailsTags(map),
      recommend: recommend,
      isFavorite: _asBool(map['isFavorite']),
      subId: map['subId']?.toString() ?? '',
    );
  }

  Map<String, String> _extractComicDetailsChapters(
    Map<String, dynamic> map, {
    required String fallbackComicId,
  }) {
    final chapters = <String, String>{};
    final chapterEntriesRaw = map['__chapterEntries'];
    if (chapterEntriesRaw is List) {
      for (final item in chapterEntriesRaw) {
        if (item is List && item.length >= 2) {
          final id = item[0].toString().trim();
          final title = item[1].toString().trim();
          if (id.isNotEmpty && title.isNotEmpty) {
            chapters[id] = title;
          }
        }
      }
    }

    if (chapters.isEmpty) {
      final chapterRaw = map['chapters'];
      if (chapterRaw is Map) {
        for (final entry in chapterRaw.entries) {
          final id = entry.key.toString().trim();
          final title = entry.value.toString().trim();
          if (id.isNotEmpty && title.isNotEmpty) {
            chapters[id] = title;
          }
        }
      }
    }

    if (chapters.isEmpty && fallbackComicId.isNotEmpty) {
      chapters[fallbackComicId] = '__default_chapter_1__';
    }
    return chapters;
  }

  Map<String, List<String>> _extractComicDetailsTags(Map<String, dynamic> map) {
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
    return tags;
  }

  List<ExploreComic> _extractComicDetailsRecommendations(
    Map<String, dynamic> map,
  ) {
    final recommend = <ExploreComic>[];
    final recommendRaw = map['recommend'];
    if (recommendRaw is List) {
      for (final item in recommendRaw) {
        if (item is! Map) {
          continue;
        }
        final recommendMap = Map<String, dynamic>.from(item);
        final id = recommendMap['id']?.toString().trim() ?? '';
        final title = recommendMap['title']?.toString().trim() ?? '';
        if (id.isEmpty || title.isEmpty) {
          continue;
        }
        final subTitle =
            (recommendMap['subTitle'] ?? recommendMap['subtitle'] ?? '')
                .toString()
                .trim();
        final cover = recommendMap['cover']?.toString().trim() ?? '';
        recommend.add(
          ExploreComic(id: id, title: title, subTitle: subTitle, cover: cover),
        );
      }
    }
    return recommend;
  }
}
