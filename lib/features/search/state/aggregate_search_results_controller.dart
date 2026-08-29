import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/source/source_capabilities.dart';

import '../support/search_shared.dart';

typedef AggregateSearchPageLoader =
    Future<SearchComicsResult> Function({
      required String sourceKey,
      required String keyword,
      required int page,
      required String order,
    });

class AggregateSearchSectionState {
  AggregateSearchSectionState({required this.source})
    : order = AggregateSearchResultsController.defaultOrderForSource(
        source.normalizedKey,
      );

  final SourceCatalogEntry source;
  String order;
  List<ExploreComic> comics = const [];
  String? errorMessage;
  bool loading = false;
  bool loadingMore = false;
  bool hasMore = true;
  int page = 0;
  int? maxPage;
  int requestToken = 0;
}

class AggregateSearchResultsController extends ChangeNotifier {
  AggregateSearchResultsController({required SourceSearchGateway sourceService})
    : _sourceService = sourceService,
      _loader = null,
      sections = sourceService.allowedSources
          .map((source) => AggregateSearchSectionState(source: source))
          .toList(growable: false);

  AggregateSearchResultsController.withLoader({
    required SourceSearchGateway sourceService,
    required AggregateSearchPageLoader loader,
  }) : _sourceService = sourceService,
       _loader = loader,
       sections = sourceService.allowedSources
           .map((source) => AggregateSearchSectionState(source: source))
           .toList(growable: false);

  final SourceSearchGateway _sourceService;
  final AggregateSearchPageLoader? _loader;
  final List<AggregateSearchSectionState> sections;

  String _keyword = '';
  bool _disposed = false;

  String get keyword => _keyword;
  bool get isLoading => sections.any((section) => section.loading);
  bool get hasResults => sections.any((section) => section.comics.isNotEmpty);

  void clear() {
    _keyword = '';
    for (final section in sections) {
      section
        ..requestToken = section.requestToken + 1
        ..comics = const []
        ..errorMessage = null
        ..loading = false
        ..loadingMore = false
        ..hasMore = true
        ..page = 0
        ..maxPage = null;
    }
    _notify();
  }

  Future<void> search(BuildContext context, String keyword) async {
    final normalized = keyword.trim();
    if (normalized.isEmpty) return;

    _keyword = normalized;
    for (final section in sections) {
      section
        ..requestToken = section.requestToken + 1
        ..comics = const []
        ..errorMessage = null
        ..loading = true
        ..loadingMore = false
        ..hasMore = true
        ..page = 0
        ..maxPage = null;
    }
    _notify();

    await Future.wait([
      for (final section in sections)
        _loadSectionPage(context, section, page: 1, append: false),
    ]);
  }

  Future<void> retry(
    BuildContext context,
    AggregateSearchSectionState section,
  ) {
    if (_keyword.isEmpty || section.loading || section.loadingMore) {
      return Future.value();
    }
    section
      ..requestToken = section.requestToken + 1
      ..errorMessage = null
      ..loading = true;
    _notify();
    return _loadSectionPage(context, section, page: 1, append: false);
  }

  Future<void> changeOrder(
    BuildContext context,
    AggregateSearchSectionState section,
    String order,
  ) {
    if (_keyword.isEmpty || section.loading || section.loadingMore) {
      return Future.value();
    }
    final normalized = _normalizeOrder(order, section.source.normalizedKey);
    if (section.order == normalized) return Future.value();

    section
      ..requestToken = section.requestToken + 1
      ..order = normalized
      ..comics = const []
      ..errorMessage = null
      ..loading = true
      ..loadingMore = false
      ..hasMore = true
      ..page = 0
      ..maxPage = null;
    _notify();
    return _loadSectionPage(context, section, page: 1, append: false);
  }

  Future<void> loadMore(
    BuildContext context,
    AggregateSearchSectionState section,
  ) {
    if (_keyword.isEmpty ||
        section.loading ||
        section.loadingMore ||
        !section.hasMore ||
        section.comics.isEmpty ||
        (section.maxPage != null && section.page >= section.maxPage!)) {
      return Future.value();
    }
    section.loadingMore = true;
    _notify();
    return _loadSectionPage(
      context,
      section,
      page: section.page + 1,
      append: true,
    );
  }

  Future<void> _loadSectionPage(
    BuildContext context,
    AggregateSearchSectionState section, {
    required int page,
    required bool append,
  }) async {
    final token = section.requestToken;
    final strings = AppLocalizations.of(context)!;
    try {
      final sourceKey = section.source.normalizedKey;
      final order = section.order;
      final loader = _loader;
      final request = loader != null
          ? loader(
              sourceKey: sourceKey,
              keyword: _keyword,
              page: page,
              order: order,
            )
          : _sourceService.searchComics(
              keyword: _keyword,
              page: page,
              order: order,
              sourceKey: sourceKey,
            );
      final result = await request.timeout(
        searchLoadTimeout,
        onTimeout: () => throw Exception(strings.searchTimeout),
      );
      if (!_isCurrent(section, token)) return;

      final previousCount = section.comics.length;
      if (append) {
        final merged = <String, ExploreComic>{
          for (final comic in section.comics)
            if (comic.id.isNotEmpty) comic.id: comic,
        };
        for (final comic in result.comics) {
          if (comic.id.isNotEmpty) merged[comic.id] = comic;
        }
        section.comics = merged.values.toList(growable: false);
      } else {
        section.comics = result.comics;
      }
      section
        ..page = page
        ..maxPage = result.maxPage
        ..errorMessage = null;
      final reachedMaxPage = result.maxPage != null && page >= result.maxPage!;
      final noNewItems = append && section.comics.length == previousCount;
      section.hasMore =
          !reachedMaxPage && result.comics.isNotEmpty && !noNewItems;
    } catch (error) {
      if (!_isCurrent(section, token)) return;
      section.errorMessage = strings.searchFailed('$error');
    } finally {
      if (_isCurrent(section, token)) {
        section
          ..loading = false
          ..loadingMore = false;
        _notify();
      }
    }
  }

  bool _isCurrent(AggregateSearchSectionState section, int token) {
    return !_disposed && token == section.requestToken;
  }

  static String defaultOrderForSource(String sourceKey) {
    if (sourceKey == copyMangaSourceKey) return '-';
    if (sourceKey == picacgSourceKey) return 'dd';
    return 'mr';
  }

  static String _normalizeOrder(String order, String sourceKey) {
    final normalized = order.trim();
    if (sourceKey == copyMangaSourceKey) {
      return copyMangaSearchModeKeys.contains(normalized) ? normalized : '-';
    }
    if (sourceKey == picacgSourceKey) {
      return picacgSearchOrderKeys.contains(normalized) ? normalized : 'dd';
    }
    return searchOrderKeys.contains(normalized) ? normalized : 'mr';
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final section in sections) {
      section.requestToken++;
    }
    super.dispose();
  }
}
