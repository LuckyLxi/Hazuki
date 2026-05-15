part of '../../hazuki_source_service.dart';

extension HazukiSourceServiceComicDetailsCapability on HazukiSourceService {
  Future<ComicDetailsData> loadComicDetails(
    String comicId, {
    String sourceKey = '',
  }) async {
    final normalizedComicId = comicId.trim();
    if (normalizedComicId.isEmpty) {
      throw Exception('comic_id_empty');
    }
    final resolvedSourceKey = _resolveActiveSourceKey(sourceKey);
    final scopedComicKey = SourceScopedComicId(
      sourceKey: resolvedSourceKey,
      comicId: normalizedComicId,
    ).storageKey;

    final memoryCached = _getComicDetailsFromMemoryCache(scopedComicKey);
    if (memoryCached != null) {
      return memoryCached;
    }

    final facade = this.facade;

    final inFlight = facade.cache.comicDetailsInFlight[scopedComicKey];
    if (inFlight != null) {
      return inFlight;
    }

    final future = _loadComicDetailsFromSource(
      normalizedComicId,
      facade,
      sourceKey: resolvedSourceKey,
    );
    facade.cache.comicDetailsInFlight[scopedComicKey] = future;
    try {
      return await future;
    } finally {
      facade.cache.comicDetailsInFlight.remove(scopedComicKey);
    }
  }

  Future<ComicDetailsData> _loadComicDetailsFromSource(
    String normalizedComicId,
    HazukiSourceFacade facade, {
    required String sourceKey,
  }) async {
    await facade.ensureInitialized();

    final engine = facade.js.engine;
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
    final dynamic resolved = await facade.js.resolve(result);
    if (resolved is! Map) {
      throw Exception('comic_details_invalid_response');
    }

    final details = _buildComicDetailsFromSourceMap(
      map: Map<String, dynamic>.from(resolved),
      normalizedComicId: normalizedComicId,
      sourceKey: sourceKey,
    );

    _putComicDetailsInMemoryCache(
      SourceScopedComicId(
        sourceKey: details.sourceKey,
        comicId: normalizedComicId,
      ).storageKey,
      details,
    );
    if (details.id != normalizedComicId) {
      _putComicDetailsInMemoryCache(details.scopedId.storageKey, details);
    }
    return details;
  }

  Future<List<String>> loadChapterImages({
    required String comicId,
    required String epId,
    String sourceKey = '',
  }) async {
    _resolveActiveSourceKey(sourceKey);
    final facade = this.facade;
    final engine = facade.js.engine;
    if (engine == null) {
      throw Exception('source_not_initialized');
    }

    final dynamic result = engine.evaluate(
      'this.__hazuki_source.comic.loadEp(${jsonEncode(comicId)}, ${jsonEncode(epId)})',
      name: 'source_chapter_images.js',
    );
    final dynamic resolved = await facade.js.resolve(result);
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
    required String sourceKey,
  }) {
    final chapters = _extractComicDetailsChapters(
      map,
      fallbackComicId: normalizedComicId,
    );
    final recommend = _extractComicDetailsRecommendations(map);
    final tags = _extractComicDetailsTags(map);

    final detailsComicId = map['id']?.toString().trim() ?? '';
    final finalComicId = detailsComicId.isEmpty
        ? normalizedComicId
        : detailsComicId;
    final updateTime = _resolveComicDetailsUpdateTime(
      map['updateTime']?.toString() ?? '',
      tags,
    );

    return ComicDetailsData(
      id: finalComicId,
      title: map['title']?.toString() ?? '',
      subTitle: (map['subTitle'] ?? map['subtitle'] ?? '').toString(),
      cover: map['cover']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      updateTime: updateTime,
      likesCount: map['likesCount']?.toString() ?? '',
      chapters: chapters,
      tags: _filterComicDetailsDisplayTags(tags),
      recommend: recommend,
      isFavorite: jsAsBool(map['isFavorite']),
      isLiked: jsAsBool(map['isLiked']),
      subId: map['subId']?.toString() ?? '',
      sourceKey: sourceKey,
    );
  }

  bool get supportComicLike {
    final engine = facade.js.engine;
    if (engine == null) return false;
    try {
      return jsAsBool(
        engine.evaluate('!!this.__hazuki_source.comic?.likeComic'),
      );
    } catch (_) {
      return false;
    }
  }

  Future<void> toggleComicLike({
    required String comicId,
    required bool isLike,
    String sourceKey = '',
  }) async {
    final normalizedComicId = comicId.trim();
    if (normalizedComicId.isEmpty) {
      throw Exception('comic_id_empty');
    }
    final resolvedSourceKey = _resolveActiveSourceKey(sourceKey);
    final facade = this.facade;
    await facade.ensureInitialized();

    await _runWithReloginRetry(() async {
      final engine = facade.js.engine;
      if (engine == null) {
        throw Exception('source_not_initialized');
      }
      if (!jsAsBool(
        engine.evaluate('!!this.__hazuki_source.comic?.likeComic'),
      )) {
        throw Exception('comic_like_not_supported');
      }

      final dynamic result = engine.evaluate(
        'this.__hazuki_source.comic.likeComic(${jsonEncode(normalizedComicId)}, $isLike)',
        name: 'source_comic_like.js',
      );
      await facade.js.resolve(result);
    });

    final scopedKey = SourceScopedComicId(
      sourceKey: resolvedSourceKey,
      comicId: normalizedComicId,
    ).storageKey;
    final cached = _getComicDetailsFromMemoryCache(scopedKey);
    if (cached != null) {
      _updateComicDetailsLikeStateInMemoryCache(
        cached.scopedId,
        isLike: isLike,
      );
    }
  }

  void _updateComicDetailsLikeStateInMemoryCache(
    SourceScopedComicId scopedId, {
    required bool isLike,
  }) {
    _updateComicDetailsStateInMemoryCache(
      scopedId,
      update: (details) => details.copyWith(isLiked: isLike),
    );
  }

  void _updateComicDetailsFavoriteStateInMemoryCache(
    SourceScopedComicId scopedId, {
    required bool isFavorite,
  }) {
    _updateComicDetailsStateInMemoryCache(
      scopedId,
      update: (details) => details.copyWith(isFavorite: isFavorite),
    );
  }

  void _updateComicDetailsStateInMemoryCache(
    SourceScopedComicId scopedId, {
    required ComicDetailsData Function(ComicDetailsData details) update,
  }) {
    final canonicalKey = scopedId.storageKey;
    final entries = _comicDetailsMemoryCache.entries.toList();
    for (final entry in entries) {
      if (entry.key != canonicalKey &&
          entry.value.scopedId.storageKey != canonicalKey) {
        continue;
      }
      _putComicDetailsInMemoryCache(entry.key, update(entry.value));
    }
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
      chapters[fallbackComicId] = hazukiDefaultChapterTitleToken;
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
    final sourceKey = activeSourceKey;
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
          ExploreComic(
            id: id,
            title: title,
            subTitle: subTitle,
            cover: cover,
            sourceKey: sourceKey,
          ),
        );
      }
    }
    return recommend;
  }
}

String _resolveComicDetailsUpdateTime(
  String explicitUpdateTime,
  Map<String, List<String>> tags,
) {
  final trimmed = explicitUpdateTime.trim();
  if (trimmed.isNotEmpty) {
    return trimmed;
  }
  for (final entry in tags.entries) {
    if (!_isComicDetailsUpdateTagKey(entry.key)) {
      continue;
    }
    for (final value in entry.value) {
      final text = value.trim();
      if (text.isNotEmpty) {
        return text;
      }
    }
  }
  return '';
}

Map<String, List<String>> _filterComicDetailsDisplayTags(
  Map<String, List<String>> tags,
) {
  final filtered = <String, List<String>>{};
  for (final entry in tags.entries) {
    if (_isComicDetailsUpdateTagKey(entry.key)) {
      continue;
    }
    filtered[entry.key] = entry.value;
  }
  return filtered;
}

bool _isComicDetailsUpdateTagKey(String key) {
  final normalized = key.trim().toLowerCase();
  return normalized == '更新' ||
      normalized == '更新时间' ||
      normalized == 'update' ||
      normalized == 'updated' ||
      normalized == 'time' ||
      normalized == 'datetime' ||
      normalized == 'datetime_updated';
}
