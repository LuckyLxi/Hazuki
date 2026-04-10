import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/hazuki_models.dart';
import '../../services/hazuki_source_service.dart';
import 'search_shared.dart';

class SearchResultsController extends ChangeNotifier {
  static const Duration _initialSearchRetryDelay = Duration(
    milliseconds: 450,
  );

  SearchResultsController({required String initialOrder})
    : _searchOrder = searchOrderKeys.contains(initialOrder)
          ? initialOrder
          : 'mr';

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
    if (_searchOrder == order) {
      return;
    }
    _searchOrder = order;
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
    final timeoutMessage = AppLocalizations.of(context)!.searchTimeout;
    return HazukiSourceService.instance
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
      final maxAttempts = _shouldRetryInitialSearch(
            page: page,
            append: append,
            silentRefresh: silentRefresh,
          )
          ? 2
          : 1;
      late final SearchComicsResult result;

      for (var attempt = 0; attempt < maxAttempts; attempt++) {
        try {
          result = await _loadSearchPage(
            context,
            keyword: normalized,
            page: page,
            order: _searchOrder,
          );
          break;
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
    super.dispose();
  }
}
