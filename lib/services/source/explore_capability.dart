import 'package:flutter/foundation.dart';

import '../../models/hazuki_models.dart';
import 'common/source_json_coerce.dart';
import 'models/source_identity.dart';
import 'runtime/source_runtime_host.dart';

typedef SourceTextTranslator = String Function(String text, {String sourceKey});

/// Loads and parses source explore data without depending on the service façade.
class SourceExploreCapability {
  SourceExploreCapability({
    required SourceRuntimeHost runtimeHost,
    required SourceTextTranslator translateSourceText,
  }) : _runtimeHost = runtimeHost,
       _translateSourceText = translateSourceText;

  final SourceRuntimeHost _runtimeHost;
  final SourceTextTranslator _translateSourceText;

  Future<List<ExploreSection>> load({bool forceRefresh = false}) async {
    final handle = _runtimeHost.activeHandle;
    final facade = handle.facade;
    await facade.ensureInitialized();

    final exploreCache = handle.exploreCache;
    if (!forceRefresh) {
      final memoryCached = exploreCache.getCachedSections();
      if (memoryCached != null) {
        return memoryCached;
      }
    } else {
      exploreCache.clearMemory();
    }

    final engine = facade.js.engine;
    if (engine == null) {
      throw Exception('source_not_initialized');
    }

    final hasExplore = facade.js.asBool(
      facade.js.evaluate('Array.isArray(this.__hazuki_source.explore)'),
    );
    if (!hasExplore) {
      return const [];
    }

    final exploreType =
        (engine.evaluate('this.__hazuki_source.explore?.[0]?.type') ?? '')
            .toString();
    if (exploreType != 'multiPartPage' &&
        exploreType != 'singlePageWithMultiPart' &&
        exploreType != 'multiPageComicList') {
      throw Exception('explore_type_not_supported:$exploreType');
    }

    final dynamic result = engine.evaluate(switch (exploreType) {
      'multiPartPage' => 'this.__hazuki_source.explore[0].load(null)',
      'singlePageWithMultiPart' => 'this.__hazuki_source.explore[0].load()',
      _ =>
        '''
Promise.all(
  this.__hazuki_source.explore
    .filter((section) => section?.type === "multiPageComicList")
    .map(async (section) => {
      try {
        return {
          title: section.title ?? "__untitled_section__",
          ...(await section.load(1))
        };
      } catch (_) {
        return null;
      }
    })
).then((sections) => sections.filter((section) => section != null))
''',
    }, name: 'source_explore_load.js');

    final dynamic resolved = await facade.js.resolve(result);
    final sections = switch (exploreType) {
      'multiPartPage' => _parseMultiPartExploreSections(resolved),
      'singlePageWithMultiPart' => _parseSinglePageWithMultiPartExploreSections(
        resolved,
      ),
      _ => _parseMultiPageComicListExploreSections(resolved),
    };

    exploreCache.putSections(sections);
    return List<ExploreSection>.unmodifiable(sections);
  }

  List<ExploreSection> _parseMultiPartExploreSections(dynamic resolved) {
    if (resolved is! List) return const [];
    final sections = <ExploreSection>[];
    for (final item in resolved) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final list = map['comics'];
      if (list is! List) continue;
      final comics = _parseExploreComics(list);
      if (comics.isNotEmpty) {
        final rawTitle = map['title']?.toString() ?? '__untitled_section__';
        final viewMore = map['viewMore']?.toString().trim();
        sections.add(
          ExploreSection(
            title: _translateSourceText(rawTitle),
            comics: comics,
            viewMoreUrl: viewMore?.isNotEmpty == true ? viewMore : null,
            offersInitialComicsFilter:
                isHazukiJmSourceKey(_runtimeHost.activeSourceKey) &&
                isJmPromotionWithUnreliableViewMore(rawTitle),
          ),
        );
      }
    }
    return markSectionsWithSharedCategoryViewMoreParameter(sections);
  }

  List<ExploreSection> _parseSinglePageWithMultiPartExploreSections(
    dynamic resolved,
  ) {
    if (resolved is! Map) return const [];
    final sections = <ExploreSection>[];
    for (final entry in Map<String, dynamic>.from(resolved).entries) {
      if (entry.value is! List) continue;
      final comics = _parseExploreComics(entry.value as List);
      if (comics.isNotEmpty) {
        sections.add(
          ExploreSection(
            title: _translateSourceText(entry.key),
            comics: comics,
          ),
        );
      }
    }
    return sections;
  }

  @visibleForTesting
  static List<ExploreSection> markSectionsWithSharedCategoryViewMoreParameter(
    List<ExploreSection> sections,
  ) {
    final parameterCounts = <String, int>{};
    for (final section in sections) {
      final parameter = _categoryViewMoreParameter(section.viewMoreUrl);
      if (parameter != null) {
        parameterCounts.update(
          parameter,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
      }
    }
    if (parameterCounts.values.every((count) => count < 2)) return sections;

    return sections
        .map((section) {
          final parameter = _categoryViewMoreParameter(section.viewMoreUrl);
          return parameter != null && parameterCounts[parameter]! > 1
              ? section.copyWith(offersInitialComicsFilter: true)
              : section;
        })
        .toList(growable: false);
  }

  static String? _categoryViewMoreParameter(String? viewMoreUrl) {
    final raw = viewMoreUrl?.trim() ?? '';
    if (!raw.startsWith('category:')) return null;
    final separator = raw.indexOf('@');
    if (separator < 0 || separator == raw.length - 1) return null;
    final parameter = raw.substring(separator + 1).trim();
    return parameter.isEmpty ? null : parameter;
  }

  @visibleForTesting
  static bool isJmPromotionWithUnreliableViewMore(String title) {
    final normalized = title.replaceAll(RegExp(r'\s+'), '');
    return RegExp(
          r'^C\d+.*(?:推薦本本|推荐本本)$',
          caseSensitive: false,
        ).hasMatch(normalized) ||
        normalized.contains('連載更新') ||
        normalized.contains('连载更新') ||
        (normalized.contains('禁漫去碼') && normalized.contains('全彩化')) ||
        (normalized.contains('禁漫去码') && normalized.contains('全彩化')) ||
        normalized.contains('禁漫漢化組') ||
        normalized.contains('禁漫汉化组');
  }

  List<ExploreSection> _parseMultiPageComicListExploreSections(
    dynamic resolved,
  ) {
    if (resolved is! List) return const [];
    final sections = <ExploreSection>[];
    for (final item in resolved) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final comicsRaw = map['comics'];
      if (comicsRaw is! List) continue;
      final comics = _parseExploreComics(comicsRaw);
      if (comics.isEmpty) continue;
      sections.add(
        ExploreSection(
          title: _translateSourceText(
            map['title']?.toString() ?? '__untitled_section__',
          ),
          comics: comics,
          viewMoreUrl: 'explore:${sections.length}',
          maxPage: _parseSourcePageCount(map['maxPage']),
        ),
      );
    }
    return sections;
  }

  int? _parseSourcePageCount(dynamic value) => switch (value) {
    int value => value,
    num value => value.toInt(),
    _ => int.tryParse(value?.toString() ?? ''),
  };

  List<ExploreComic> _parseExploreComics(List list) {
    final comics = <ExploreComic>[];
    for (final comic in list) {
      if (comic is! Map) continue;
      final map = Map<String, dynamic>.from(comic);
      comics.add(
        ExploreComic(
          id: map['id']?.toString() ?? '',
          title: map['title']?.toString() ?? '',
          subTitle: (map['subTitle'] ?? map['subtitle'] ?? '').toString(),
          cover: map['cover']?.toString() ?? '',
          sourceKey: _runtimeHost.activeSourceKey,
          tags: jsAsStringList(map['tags']),
        ),
      );
    }
    return comics;
  }
}
