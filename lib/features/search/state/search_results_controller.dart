import 'package:flutter/material.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/hazuki_source_service.dart';

import '../support/search_shared.dart';

class SearchResultsController extends ChangeNotifier {
  static const Duration _initialSearchRetryDelay = Duration(milliseconds: 450);

  SearchResultsController({
    required String initialOrder,
    required HazukiSourceService sourceService,
    SearchPageLoader? searchPageLoader,
    SearchComicDetailsLoader? comicDetailsLoader,
  }) : _searchPageLoader = searchPageLoader,
       _comicDetailsLoader = comicDetailsLoader,
       _sourceService = sourceService,
       _searchOrder = _normalizeSearchOrder(
         initialOrder,
         sourceService.activeSourceKey,
       ) {
    _sourceService.addListener(_onSourceChanged);
  }

  final SearchPageLoader? _searchPageLoader;
  final SearchComicDetailsLoader? _comicDetailsLoader;
  final HazukiSourceService _sourceService;

  String _searchKeyword = '';
  String? _searchErrorMessage;
  List<ExploreComic> _searchComics = const [];
  bool _searchLoading = false;
  bool _searchLoadingMore = false;
  bool _searchHasMore = true;
  int _searchPage = 1;
  int? _searchMaxPage;
  int _searchRequestToken = 0;
  String _searchOrder;
  bool _disposed = false;

  String get searchKeyword => _searchKeyword;
  String? get searchErrorMessage => _searchErrorMessage;
  List<ExploreComic> get searchComics => _searchComics;
  bool get searchLoading => _searchLoading;
  bool get searchLoadingMore => _searchLoadingMore;
  bool get searchHasMore => _searchHasMore;
  int get searchPage => _searchPage;
  int? get searchMaxPage => _searchMaxPage;
  String get searchOrder => _searchOrder;

  SourceRuntimeState get sourceRuntimeState =>
      _sourceService.sourceRuntimeState;
  bool get canRetry => sourceRuntimeState.canRetry;

  void logRuntimeRetryRequested(String source) =>
      _sourceService.logRuntimeRetryRequested(source);

  static String _normalizeSearchOrder(String order, String sourceKey) {
    final normalized = order.trim();
    if (sourceKey.trim() == copyMangaSourceKey) {
      return copyMangaSearchModeKeys.contains(normalized) ? normalized : '-';
    }
    if (sourceKey.trim() == picacgSourceKey) {
      return picacgSearchOrderKeys.contains(normalized) ? normalized : 'dd';
    }
    return searchOrderKeys.contains(normalized) ? normalized : 'mr';
  }

  void _onSourceChanged() {
    final nextOrder = _normalizeSearchOrder(
      _searchOrder,
      _sourceService.activeSourceKey,
    );
    if (nextOrder != _searchOrder) {
      _searchOrder = nextOrder;
    }
    _notify();
  }

  void clearSearchData() {
    _searchRequestToken++;
    _searchKeyword = '';
    _searchErrorMessage = null;
    _searchComics = const [];
    _searchLoading = false;
    _searchLoadingMore = false;
    _searchHasMore = true;
    _searchPage = 1;
    _searchMaxPage = null;
    _notify();
  }

  void setSearchOrder(String order) {
    final normalized = _normalizeSearchOrder(
      order,
      _sourceService.activeSourceKey,
    );
    if (_searchOrder == normalized) {
      return;
    }
    _searchOrder = normalized;
    _notify();
  }

  int prepareDirectIdLookup(String keyword) {
    final requestToken = ++_searchRequestToken;
    _searchKeyword = keyword;
    _searchErrorMessage = null;
    _searchComics = const [];
    _searchLoading = true;
    _searchLoadingMore = false;
    _searchHasMore = true;
    _searchPage = 1;
    _searchMaxPage = null;
    _notify();
    return requestToken;
  }

  bool isCurrentRequest(int token) => token == _searchRequestToken;

  Future<ComicDetailsData> loadComicById(
    String comicId, {
    String sourceKey = '',
  }) {
    final overrideLoader = _comicDetailsLoader;
    if (overrideLoader != null) {
      return overrideLoader(
        comicId,
        sourceKey: sourceKey,
      ).timeout(searchLoadTimeout);
    }
    return _sourceService
        .loadComicDetails(comicId, sourceKey: sourceKey)
        .timeout(searchLoadTimeout);
  }

  void finishDirectIdLookup(int token) {
    if (!isCurrentRequest(token)) {
      return;
    }
    _searchLoading = false;
    _notify();
  }

  Future<SearchComicsResult> _loadSearchPage(
    BuildContext context, {
    required String keyword,
    required int page,
    required String order,
  }) {
    final overrideLoader = _searchPageLoader;
    if (overrideLoader != null) {
      return overrideLoader(
        context,
        keyword: keyword,
        page: page,
        order: order,
      );
    }
    final timeoutMessage = AppLocalizations.of(context)!.searchTimeout;
    return _sourceService
        .searchComics(keyword: keyword, page: page, order: order)
        .timeout(
          searchLoadTimeout,
          onTimeout: () {
            throw Exception(timeoutMessage);
          },
        );
  }

  bool _shouldRetryInitialSearch({
    required int page,
    required bool append,
    required bool silentRefresh,
  }) {
    return page == 1 && !append && !silentRefresh;
  }

  Future<void> search(
    BuildContext context, {
    required String keyword,
    required int page,
    bool append = false,
    bool silentRefresh = false,
  }) async {
    final strings = AppLocalizations.of(context)!;
    final normalized = keyword.trim();
    if (normalized.isEmpty) {
      return;
    }

    final requestToken = ++_searchRequestToken;
    final isLoadMore = append;

    _searchKeyword = normalized;
    _searchErrorMessage = null;
    if (!isLoadMore) {
      _searchLoadingMore = false;
    }
    if (!isLoadMore && !silentRefresh) {
      _searchPage = 1;
      _searchMaxPage = null;
      _searchHasMore = true;
      _searchComics = const [];
    }
    if (isLoadMore) {
      _searchLoadingMore = true;
    } else if (!silentRefresh) {
      _searchLoading = true;
    }
    _notify();

    try {
      final maxAttempts =
          _shouldRetryInitialSearch(
            page: page,
            append: append,
            silentRefresh: silentRefresh,
          )
          ? 5
          : 1;
      late SearchComicsResult result;

      for (var attempt = 0; attempt < maxAttempts; attempt++) {
        try {
          result = await _loadSearchPage(
            context,
            keyword: normalized,
            page: page,
            order: _searchOrder,
          );
          final hasRemainingAttempt = attempt + 1 < maxAttempts;
          if (result.comics.isNotEmpty || !hasRemainingAttempt) {
            break;
          }
          await Future<void>.delayed(_initialSearchRetryDelay);
          if (!isCurrentRequest(requestToken)) {
            return;
          }
        } catch (error) {
          final hasRemainingAttempt = attempt + 1 < maxAttempts;
          if (!hasRemainingAttempt) {
            rethrow;
          }
          await Future<void>.delayed(_initialSearchRetryDelay);
          if (!isCurrentRequest(requestToken)) {
            return;
          }
        }
      }

      if (!isCurrentRequest(requestToken)) {
        return;
      }

      final previousCount = _searchComics.length;
      if (append) {
        final merged = <String, ExploreComic>{
          for (final comic in _searchComics)
            if (comic.id.isNotEmpty) comic.id: comic,
        };
        for (final comic in result.comics) {
          if (comic.id.isNotEmpty) {
            merged[comic.id] = comic;
          }
        }
        _searchComics = merged.values.toList();
      } else {
        _searchComics = result.comics;
      }
      _searchPage = page;
      _searchMaxPage = result.maxPage;
      final reachedMaxPage = result.maxPage != null && page >= result.maxPage!;
      final noNewItems = append && _searchComics.length == previousCount;
      _searchHasMore =
          !reachedMaxPage && result.comics.isNotEmpty && !noNewItems;
      _searchErrorMessage = null;
    } catch (e) {
      if (!isCurrentRequest(requestToken)) {
        return;
      }
      _searchErrorMessage = strings.searchFailed('$e');
    } finally {
      if (isCurrentRequest(requestToken)) {
        if (isLoadMore) {
          _searchLoadingMore = false;
        } else if (!silentRefresh) {
          _searchLoading = false;
        }
        _notify();
      }
    }
  }

  Future<void> loadMoreSearch(BuildContext context) async {
    if (_searchKeyword.isEmpty ||
        _searchLoading ||
        _searchLoadingMore ||
        !_searchHasMore ||
        (_searchMaxPage != null && _searchPage >= _searchMaxPage!)) {
      return;
    }

    if (_searchComics.isEmpty) {
      return;
    }

    await search(
      context,
      keyword: _searchKeyword,
      page: _searchPage + 1,
      append: true,
    );
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _sourceService.removeListener(_onSourceChanged);
    super.dispose();
  }
}
