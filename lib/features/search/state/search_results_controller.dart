import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/services/source/plugins/source_sort_options.dart';

import '../support/search_contracts.dart';
import '../support/search_task_lifetime.dart';
import 'package:hazuki/services/source/interaction/source_ui_scope.dart';
import 'package:hazuki/services/source/interaction/source_ui_service.dart';

class SearchResultsController extends ChangeNotifier {
  static const Duration _initialSearchRetryDelay = Duration(milliseconds: 450);

  SearchResultsController({
    required String initialOrder,
    required SourceSearchGateway sourceService,
    required this.taskControl,
    SearchPageLoader? searchPageLoader,
    SearchComicDetailsLoader? comicDetailsLoader,
  }) : _searchPageLoader = searchPageLoader,
       _comicDetailsLoader = comicDetailsLoader,
       _sourceService = sourceService,
       _searchOrder = initialOrder.trim() {
    _searchOrder = _normalizeSearchOrder(_searchOrder);
    _lastSourceEpoch = _sourceEpoch;
    _lastSourceKey = _sourceService.activeSourceKey;
    _sourceService.addListener(_onSourceChanged);
  }

  final SearchPageLoader? _searchPageLoader;
  final SearchComicDetailsLoader? _comicDetailsLoader;
  final SourceSearchGateway _sourceService;
  final SourceTaskControlGateway taskControl;
  SourceTaskCancellation _requestLifetime = SourceTaskCancellation();
  final String _taskOwnerId = createSourceTaskId();
  final SourceUiOwner _sourceUi = SourceUiOwner();
  String? _taskGroupId;

  void stopPending(SourceTaskStopReason reason) {
    _searchRequestToken++;
    _requestLifetime.cancel(reason);
    _sourceUi.cancel(
      reason == SourceTaskStopReason.ownerDisposed ? 'ownerGone' : reason.name,
    );
    _searchLoading = false;
    _searchLoadingMore = false;
    taskControl
        .cancelOwner(_taskOwnerId, reason)
        .then<void>((receipt) => receipt.whenSettled.ignore())
        .ignore();
  }

  String _searchKeyword = '';
  SearchMessages? _lastSearchMessages;
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
  late String _lastSourceEpoch;
  String? _lastSourceKey;
  String get _sourceEpoch {
    final id = _sourceService.activeSourceKey;
    final source = _sourceService.allowedSources
        .where((source) => source.key == id)
        .firstOrNull;
    return '$id|${source?.pluginVersion}|${source?.pluginDirectory}';
  }

  String get searchKeyword => _searchKeyword;
  String? get searchErrorMessage => _searchErrorMessage;
  List<ExploreComic> get searchComics => _searchComics;
  bool get searchLoading => _searchLoading;
  bool get searchLoadingMore => _searchLoadingMore;
  bool get searchHasMore => _searchHasMore;
  int get searchPage => _searchPage;
  int? get searchMaxPage => _searchMaxPage;
  String get searchOrder => _searchOrder;

  SourceRuntimeState get sourceRuntimeState => _sourceService.runtimeState;
  bool get canRetry => sourceRuntimeState.canRetry;

  void logRuntimeRetryRequested(String source) =>
      _sourceService.logRuntimeRetryRequested(source);

  String _normalizeSearchOrder(String order) => normalizeSourceSearchOrder(
    order,
    _sourceService.allowedSources
            .where((source) => source.key == _sourceService.activeSourceKey)
            .firstOrNull
            ?.presentation ??
        const {},
  );

  void _onSourceChanged() {
    final sourceChanged = _sourceEpoch != _lastSourceEpoch;
    if (sourceChanged) {
      final oldSourceRemoved = !_sourceService.allowedSources.any(
        (source) => source.key == _lastSourceKey,
      );
      stopPending(
        oldSourceRemoved
            ? SourceTaskStopReason.pluginDisabled
            : _lastSourceKey == _sourceService.activeSourceKey
            ? SourceTaskStopReason.pluginUpdated
            : SourceTaskStopReason.sourceChanged,
      );
      _lastSourceKey = _sourceService.activeSourceKey;
      _lastSourceEpoch = _sourceEpoch;
      _lastSearchMessages = null;
      _searchRequestToken++;
      _searchComics = const [];
      _searchLoading = false;
      _searchLoadingMore = false;
      _searchErrorMessage = null;
    }
    final nextOrder = _normalizeSearchOrder(_searchOrder);
    if (nextOrder != _searchOrder) {
      _searchOrder = nextOrder;
      final messages = _lastSearchMessages;
      if (!sourceChanged && messages != null && _searchKeyword.isNotEmpty) {
        unawaited(search(messages, keyword: _searchKeyword, page: 1));
        return;
      }
    }
    _notify();
  }

  void clearSearchData() {
    stopPending(SourceTaskStopReason.superseded);
    _sourceUi.restart();
    _searchRequestToken++;
    _searchKeyword = '';
    _lastSearchMessages = null;
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
    final normalized = _normalizeSearchOrder(order);
    if (_searchOrder == normalized) {
      return;
    }
    _searchOrder = normalized;
    _notify();
  }

  int prepareDirectIdLookup(String keyword) {
    stopPending(SourceTaskStopReason.superseded);
    _requestLifetime = SourceTaskCancellation();
    _taskGroupId = createSourceTaskId();
    _sourceUi.restart();
    final requestToken = ++_searchRequestToken;
    _lastSearchMessages = null;
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
    final lifetime = _requestLifetime;
    final token = _searchRequestToken;
    final origin = SourceTaskOrigin(
      ownerId: _taskOwnerId,
      groupId: _taskGroupId ??= createSourceTaskId(),
      requestSequence: token,
      cancellation: lifetime,
      resultDisposition: () => _disposed
          ? SourceTaskResultDisposition.disposed
          : lifetime.reason == SourceTaskStopReason.deadlineExceeded
          ? SourceTaskResultDisposition.timedOut
          : isCurrentRequest(token)
          ? SourceTaskResultDisposition.current
          : SourceTaskResultDisposition.superseded,
    );
    return _sourceUi.run(
      () => runSearchOperation(
        () =>
            _comicDetailsLoader?.call(comicId, sourceKey: sourceKey) ??
            _sourceService.loadComicDetails(
              comicId,
              sourceKey: sourceKey,
              taskOrigin: origin,
            ),
        lifetime,
      ),
    );
  }

  void finishDirectIdLookup(int token) {
    if (!isCurrentRequest(token)) {
      return;
    }
    _searchLoading = false;
    _notify();
  }

  Future<SearchComicsResult> _loadSearchPage(
    SearchMessages messages, {
    required String keyword,
    required int page,
    required String order,
    required String groupId,
    required int requestToken,
  }) {
    final overrideLoader = _searchPageLoader;
    if (overrideLoader != null) {
      return runSearchOperation(
        () => overrideLoader(keyword: keyword, page: page, order: order),
        _requestLifetime,
      );
    }
    final lifetime = _requestLifetime;
    final taskOrigin = SourceTaskOrigin(
      ownerId: _taskOwnerId,
      groupId: groupId,
      requestSequence: requestToken,
      cancellation: lifetime,
      resultDisposition: () {
        if (_disposed) return SourceTaskResultDisposition.disposed;
        if (lifetime.reason == SourceTaskStopReason.deadlineExceeded) {
          return SourceTaskResultDisposition.timedOut;
        }
        return isCurrentRequest(requestToken)
            ? SourceTaskResultDisposition.current
            : SourceTaskResultDisposition.superseded;
      },
    );
    return runSearchOperation(
      () => _sourceService.searchComics(
        keyword: keyword,
        page: page,
        order: order,
        taskOrigin: taskOrigin,
      ),
      lifetime,
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
    SearchMessages messages, {
    required String keyword,
    required int page,
    bool append = false,
    bool silentRefresh = false,
  }) async {
    if (keyword.trim().isEmpty || _disposed) return;
    if (!append) {
      stopPending(SourceTaskStopReason.superseded);
    } else {
      _requestLifetime.cancel(SourceTaskStopReason.superseded);
    }
    _requestLifetime = SourceTaskCancellation();
    _sourceUi.restart();
    final nextRequestToken = _searchRequestToken + 1;
    Future<void> work() => _search(
      messages,
      keyword: keyword,
      page: page,
      append: append,
      silentRefresh: silentRefresh,
    );
    try {
      if (silentRefresh) {
        await SourceUiScope.withoutInteraction(work);
      } else {
        await _sourceUi.run(work);
      }
    } catch (error) {
      if (!_disposed && isCurrentRequest(nextRequestToken)) {
        _searchLoading = false;
        _searchLoadingMore = false;
        _searchErrorMessage = isSilentSearchStop(error)
            ? null
            : searchFailureMessage(error, messages);
        _notify();
      }
    }
  }

  Future<void> _search(
    SearchMessages messages, {
    required String keyword,
    required int page,
    bool append = false,
    bool silentRefresh = false,
  }) async {
    final normalized = keyword.trim();
    if (normalized.isEmpty) {
      return;
    }

    final requestToken = ++_searchRequestToken;
    final lifetime = _requestLifetime;
    final isLoadMore = append;
    if (!append || _taskGroupId == null) _taskGroupId = createSourceTaskId();
    final groupId = _taskGroupId!;

    _searchKeyword = normalized;
    _lastSearchMessages = messages;
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
            messages,
            keyword: normalized,
            page: page,
            order: _searchOrder,
            groupId: groupId,
            requestToken: requestToken,
          );
          final hasRemainingAttempt = attempt + 1 < maxAttempts;
          if (result.comics.isNotEmpty ||
              !hasRemainingAttempt ||
              _sourceUi.wasCancelled) {
            break;
          }
          await waitForSearchRetry(_initialSearchRetryDelay, lifetime);
          if (!isCurrentRequest(requestToken)) {
            return;
          }
        } catch (error) {
          // 运行时故障不自动重试：重试会把已接纳的搜索重放到重建后的实例。
          if (isSilentSearchStop(error) ||
              error is SourceRuntimeFailed ||
              _sourceUi.wasCancelled ||
              lifetime.reason != null) {
            rethrow;
          }
          final hasRemainingAttempt = attempt + 1 < maxAttempts;
          if (!hasRemainingAttempt) {
            rethrow;
          }
          await waitForSearchRetry(_initialSearchRetryDelay, lifetime);
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
      _searchErrorMessage = isSilentSearchStop(e)
          ? null
          : searchFailureMessage(e, messages);
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

  Future<void> loadMoreSearch(SearchMessages messages) async {
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
      messages,
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
    stopPending(SourceTaskStopReason.ownerDisposed);
    _sourceUi.dispose();
    _searchRequestToken++;
    _sourceService.removeListener(_onSourceChanged);
    super.dispose();
  }
}
