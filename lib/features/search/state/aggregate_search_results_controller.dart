import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/services/source/plugins/source_sort_options.dart';

import '../support/search_contracts.dart';
import '../support/search_task_lifetime.dart';
import 'package:hazuki/services/source/interaction/source_ui_service.dart';

typedef AggregateSearchPageLoader =
    Future<SearchComicsResult> Function({
      required String sourceKey,
      required String keyword,
      required int page,
      required String order,
    });

class AggregateSearchSectionState {
  AggregateSearchSectionState({required this.source})
    : order = normalizeSourceSearchOrder('', source.presentation);

  SourceCatalogEntry source;
  final SourceUiOwner sourceUi = SourceUiOwner();
  String order;
  List<ExploreComic> comics = const [];
  String? errorMessage;
  bool loading = false;
  bool loadingMore = false;
  bool hasMore = true;
  int page = 0;
  int? maxPage;
  int requestToken = 0;
  String taskGroupId = createSourceTaskId();
  SourceTaskCancellation lifetime = SourceTaskCancellation();
}

class AggregateSearchResultsController extends ChangeNotifier {
  AggregateSearchResultsController({
    required SourceSearchGateway sourceService,
    required this.taskControl,
  }) : _sourceService = sourceService,
       _loader = null,
       sections = sourceService.allowedSources
           .map((source) => AggregateSearchSectionState(source: source))
           .toList() {
    _sourceService.addListener(_syncSources);
  }

  AggregateSearchResultsController.withLoader({
    required SourceSearchGateway sourceService,
    required this.taskControl,
    required AggregateSearchPageLoader loader,
  }) : _sourceService = sourceService,
       _loader = loader,
       sections = sourceService.allowedSources
           .map((source) => AggregateSearchSectionState(source: source))
           .toList() {
    _sourceService.addListener(_syncSources);
  }

  final SourceSearchGateway _sourceService;
  final SourceTaskControlGateway taskControl;
  final AggregateSearchPageLoader? _loader;
  final List<AggregateSearchSectionState> sections;
  final String _taskOwnerId = createSourceTaskId();

  String _keyword = '';
  SearchMessages? _lastMessages;
  bool _disposed = false;

  String get keyword => _keyword;
  bool get isLoading => sections.any((section) => section.loading);
  bool get hasResults => sections.any((section) => section.comics.isNotEmpty);

  void _stopSection(
    AggregateSearchSectionState section,
    SourceTaskStopReason reason,
  ) {
    section.lifetime.cancel(reason);
    section.sourceUi.cancel(
      reason == SourceTaskStopReason.ownerDisposed ? 'ownerGone' : reason.name,
    );
    taskControl
        .cancelGroup(
          ownerId: _taskOwnerId,
          groupId: section.taskGroupId,
          pluginId: section.source.normalizedKey,
          reason: reason,
        )
        .then<void>((receipt) => receipt.whenSettled.ignore())
        .ignore();
  }

  void stopPending(SourceTaskStopReason reason) {
    for (final section in sections) {
      section.requestToken++;
      section.lifetime.cancel(reason);
      section.sourceUi.cancel(
        reason == SourceTaskStopReason.ownerDisposed
            ? 'ownerGone'
            : reason.name,
      );
      section.loading = false;
      section.loadingMore = false;
    }
    taskControl
        .cancelOwner(_taskOwnerId, reason)
        .then<void>((receipt) => receipt.whenSettled.ignore())
        .ignore();
  }

  void clear() {
    stopPending(SourceTaskStopReason.superseded);
    _keyword = '';
    for (final section in sections) {
      section.sourceUi.restart();
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

  Future<void> search(SearchMessages messages, String keyword) async {
    final normalized = keyword.trim();
    if (normalized.isEmpty) return;
    stopPending(SourceTaskStopReason.superseded);

    _keyword = normalized;
    _lastMessages = messages;
    final groupId = createSourceTaskId();
    for (final section in sections) {
      section.sourceUi.restart();
      section
        ..taskGroupId = groupId
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
        _loadSectionPage(messages, section, page: 1, append: false),
    ]);
  }

  Future<void> retry(
    SearchMessages messages,
    AggregateSearchSectionState section,
  ) {
    if (_keyword.isEmpty || section.loading || section.loadingMore) {
      return Future.value();
    }
    _stopSection(section, SourceTaskStopReason.superseded);
    section
      ..requestToken = section.requestToken + 1
      ..errorMessage = null
      ..loading = true;
    _notify();
    return _loadSectionPage(messages, section, page: 1, append: false);
  }

  Future<void> changeOrder(
    SearchMessages messages,
    AggregateSearchSectionState section,
    String order,
  ) {
    if (_keyword.isEmpty || section.loading || section.loadingMore) {
      return Future.value();
    }
    final normalized = _normalizeOrder(order, section.source.normalizedKey);
    if (section.order == normalized) return Future.value();
    _stopSection(section, SourceTaskStopReason.superseded);

    section
      ..requestToken = section.requestToken + 1
      ..order = normalized
      ..taskGroupId = createSourceTaskId()
      ..comics = const []
      ..errorMessage = null
      ..loading = true
      ..loadingMore = false
      ..hasMore = true
      ..page = 0
      ..maxPage = null;
    _notify();
    return _loadSectionPage(messages, section, page: 1, append: false);
  }

  Future<void> loadMore(
    SearchMessages messages,
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
      messages,
      section,
      page: section.page + 1,
      append: true,
    );
  }

  Future<void> _loadSectionPage(
    SearchMessages messages,
    AggregateSearchSectionState section, {
    required int page,
    required bool append,
  }) async {
    final token = section.requestToken;
    section.lifetime = SourceTaskCancellation();
    section.sourceUi.restart();
    try {
      await section.sourceUi.run(
        () => _loadSectionPageWithUi(
          messages,
          section,
          page: page,
          append: append,
        ),
      );
    } catch (error) {
      if (!_isCurrent(section, token)) return;
      section
        ..errorMessage = isSilentSearchStop(error)
            ? null
            : searchFailureMessage(error, messages)
        ..loading = false
        ..loadingMore = false;
      _notify();
    }
  }

  Future<void> _loadSectionPageWithUi(
    SearchMessages messages,
    AggregateSearchSectionState section, {
    required int page,
    required bool append,
  }) async {
    final token = section.requestToken;
    final lifetime = section.lifetime;
    final taskOrigin = SourceTaskOrigin(
      ownerId: _taskOwnerId,
      groupId: section.taskGroupId,
      requestSequence: token,
      cancellation: lifetime,
      resultDisposition: () {
        if (_disposed) return SourceTaskResultDisposition.disposed;
        if (lifetime.reason == SourceTaskStopReason.deadlineExceeded) {
          return SourceTaskResultDisposition.timedOut;
        }
        return _isCurrent(section, token)
            ? SourceTaskResultDisposition.current
            : SourceTaskResultDisposition.superseded;
      },
    );
    try {
      final sourceKey = section.source.normalizedKey;
      final order = section.order;
      final loader = _loader;
      Future<SearchComicsResult> request() => loader != null
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
              taskOrigin: taskOrigin,
            );
      final result = await runSearchOperation(request, lifetime);
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
      section.errorMessage = isSilentSearchStop(error)
          ? null
          : searchFailureMessage(error, messages);
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
    return !_disposed &&
        sections.contains(section) &&
        token == section.requestToken;
  }

  void _syncSources() {
    final current = {
      for (final section in sections) section.source.key: section,
    };
    final updated = <AggregateSearchSectionState>[];
    final reload = <AggregateSearchSectionState>[];
    for (final source in _sourceService.allowedSources) {
      final previous = current.remove(source.key);
      if (previous != null &&
          previous.source.pluginDirectory == source.pluginDirectory &&
          previous.source.pluginVersion == source.pluginVersion) {
        previous.source = source;
        final order = normalizeSourceSearchOrder(
          previous.order,
          source.presentation,
        );
        if (order != previous.order) {
          _stopSection(previous, SourceTaskStopReason.superseded);
          previous
            ..requestToken = previous.requestToken + 1
            ..order = order
            ..taskGroupId = createSourceTaskId()
            ..comics = const []
            ..errorMessage = null
            ..page = 0
            ..maxPage = null
            ..hasMore = true
            ..loadingMore = false
            ..loading = _keyword.isNotEmpty && _lastMessages != null;
          if (previous.loading) reload.add(previous);
        }
        updated.add(previous);
      } else {
        if (previous != null) {
          _stopSection(previous, SourceTaskStopReason.pluginUpdated);
          previous.sourceUi.dispose();
          previous.requestToken++;
        }
        updated.add(AggregateSearchSectionState(source: source));
      }
    }
    for (final removed in current.values) {
      _stopSection(removed, SourceTaskStopReason.pluginDisabled);
      removed.sourceUi.dispose();
      removed.requestToken++;
    }
    sections
      ..clear()
      ..addAll(updated);
    _notify();
    for (final section in reload) {
      unawaited(
        _loadSectionPage(_lastMessages!, section, page: 1, append: false),
      );
    }
  }

  static String defaultOrderForSource(String sourceKey) => '';
  String _normalizeOrder(String order, String sourceKey) {
    final source = sections
        .where((s) => s.source.key == sourceKey)
        .firstOrNull
        ?.source;
    return normalizeSourceSearchOrder(order, source?.presentation ?? const {});
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    stopPending(SourceTaskStopReason.ownerDisposed);
    _sourceService.removeListener(_syncSources);
    for (final section in sections) {
      section.sourceUi.dispose();
      section.requestToken++;
    }
    super.dispose();
  }
}
