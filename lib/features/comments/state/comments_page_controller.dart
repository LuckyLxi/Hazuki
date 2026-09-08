import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:hazuki/features/comments/support/comments_content_support.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/comment_filter_service.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/shared/comments/comments_interaction_state.dart';

enum CommentsEffectType {
  initialLoadStarted,
  liked,
  unliked,
  likeFailed,
  loginRequired,
  sendUnsupported,
  sendSucceeded,
  sendFailed,
}

class CommentsEffect {
  const CommentsEffect(this.type, {this.error});

  final CommentsEffectType type;
  final Object? error;
}

class CommentsPageController extends ChangeNotifier {
  CommentsPageController({
    required SourceCommentsGateway sourceService,
    required CommentFilterService filterService,
    required this.comicId,
    this.subId,
    this.chapterId,
    this.sourceKey = '',
    this.logSource = 'comments',
    this.logContext = const {},
    CommentsInteractionState? state,
  }) : _sourceService = sourceService,
       _filterService = filterService,
       state = state ?? CommentsInteractionState() {
    _filterService.addListener(_onFilterChanged);
  }

  static const pageSize = 16;
  static const loadTimeout = Duration(seconds: 20);

  final String comicId;
  final String? subId;
  final String? chapterId;
  final String sourceKey;
  final String logSource;
  final Map<String, Object?> logContext;
  final CommentsInteractionState state;
  final SourceCommentsGateway _sourceService;
  final CommentFilterService _filterService;
  final _effects = StreamController<CommentsEffect>.broadcast(sync: true);
  bool _disposed = false;

  Stream<CommentsEffect> get effects => _effects.stream;

  bool get isLogged => sourceKey.trim().isEmpty
      ? _sourceService.isLogged
      : _sourceService.isLoggedForSource(sourceKey);

  bool get supportCommentSend => sourceKey.trim().isEmpty
      ? _sourceService.supportCommentSend
      : _sourceService.supportCommentSendForSource(sourceKey);

  void initialize() {
    if (_disposed) return;
    _refreshCapabilities();
    if (!state.initialLoadSucceeded) unawaited(loadInitial());
  }

  void _refreshCapabilities() {
    state.supportCommentLike = sourceKey.trim().isEmpty
        ? _sourceService.supportCommentLike
        : _sourceService.supportCommentLikeForSource(sourceKey);
    state.supportCommentReplies = _sourceService.supportCommentRepliesForSource(
      sourceKey,
    );
  }

  Future<ComicCommentsPageResult> _loadPage(int page, {String? replyTo}) {
    return _sourceService
        .loadCommentsPage(
          comicId: comicId,
          subId: subId,
          chapterId: chapterId,
          sourceKey: sourceKey,
          page: page,
          pageSize: pageSize,
          replyTo: replyTo,
        )
        .timeout(loadTimeout);
  }

  bool _isCurrent(int epoch) => !_disposed && state.loadEpoch == epoch;

  void _update(VoidCallback update) {
    if (_disposed) return;
    update();
    notifyListeners();
  }

  void _emit(CommentsEffectType type, {Object? error}) {
    if (!_disposed) _effects.add(CommentsEffect(type, error: error));
  }

  Future<void> loadInitial() async {
    if (_disposed) return;
    final epoch = ++state.loadEpoch;
    _emit(CommentsEffectType.initialLoadStarted);
    _update(() {
      state.initialLoading = true;
      state.loadingMore = false;
    });
    final startedAt = DateTime.now();
    _logEvent('Comments load started', content: {'page': 1});
    try {
      final result = await _loadPage(1);
      if (!_isCurrent(epoch)) return;
      _update(() {
        state.comments = result.comments;
        state.loadError = null;
        state.initialLoadSucceeded = true;
        _refreshCapabilities();
        state.currentPage = 1;
        state.maxPage = result.maxPage;
        state.hasMore = _hasMore(1, result.comments.length, result.maxPage);
      });
      _logEvent(
        'Comments load succeeded',
        content: {
          'page': 1,
          'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
          'fetchedCount': result.comments.length,
          'maxPage': result.maxPage,
        },
      );
    } catch (error) {
      if (!_isCurrent(epoch)) return;
      _update(() => state.loadError = error);
      _logEvent(
        'Comments load failed',
        level: 'error',
        content: {
          'page': 1,
          'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
          'error': error.toString(),
        },
      );
    } finally {
      if (_isCurrent(epoch)) {
        _update(() => state.initialLoading = false);
        _maybeLoadMoreForHiddenFilter();
      }
    }
  }

  Future<void> loadMore() async {
    if (_disposed ||
        state.initialLoading ||
        state.loadingMore ||
        !state.hasMore) {
      return;
    }
    final epoch = state.loadEpoch;
    final nextPage = state.currentPage + 1;
    final startedAt = DateTime.now();
    _logEvent('Comments load more started', content: {'page': nextPage});
    if (state.maxPage != null && state.currentPage >= state.maxPage!) {
      _update(() => state.hasMore = false);
      return;
    }
    _update(() => state.loadingMore = true);
    try {
      final result = await _loadPage(nextPage);
      if (!_isCurrent(epoch)) return;
      final merged = _mergeComments(state.comments, result.comments);
      final appendedCount = merged.length - state.comments.length;
      _update(() {
        state.comments = merged;
        state.currentPage = nextPage;
        state.maxPage = result.maxPage ?? state.maxPage;
        state.hasMore =
            _hasMore(nextPage, result.comments.length, state.maxPage) &&
            appendedCount > 0;
        state.loadingMore = false;
      });
      _logEvent(
        'Comments load more succeeded',
        content: {
          'page': nextPage,
          'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
          'fetchedCount': result.comments.length,
          'appendedCount': appendedCount,
          'maxPage': state.maxPage,
        },
      );
      _maybeLoadMoreForHiddenFilter();
    } catch (_) {
      if (!_isCurrent(epoch)) return;
      _update(() => state.loadingMore = false);
      _logEvent(
        'Comments load more failed',
        level: 'error',
        content: {
          'page': nextPage,
          'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
        },
      );
    }
  }

  void setReplyTarget(ComicCommentData comment) {
    if (comment.id != null) _update(() => state.replyToComment = comment);
  }

  void clearReplyTarget() {
    if (state.replyToComment != null) {
      _update(() => state.replyToComment = null);
    }
  }

  Future<void> toggleCommentLike(ComicCommentData comment) async {
    final id = comment.id;
    if (_disposed || id == null || state.likingCommentIds.contains(id)) return;
    final epoch = state.loadEpoch;
    final nextLiked = !(comment.isLiked ?? false);
    _update(() {
      state.likingCommentIds.add(id);
      _updateCommentById(id, (current) {
        final score = current.score ?? 0;
        final nextScore = nextLiked == (current.isLiked ?? false)
            ? score
            : score + (nextLiked ? 1 : -1);
        return current.copyWith(
          isLiked: nextLiked,
          score: math.max(0, nextScore),
        );
      });
    });
    try {
      await _sourceService.likeComment(
        comicId: comicId,
        subId: subId,
        sourceKey: sourceKey,
        commentId: id,
        isLike: nextLiked,
      );
      _emit(nextLiked ? CommentsEffectType.liked : CommentsEffectType.unliked);
    } catch (error) {
      if (_isCurrent(epoch)) {
        _update(() => _updateCommentById(id, (_) => comment));
      }
      _emit(CommentsEffectType.likeFailed, error: error);
    } finally {
      _update(() => state.likingCommentIds.remove(id));
    }
  }

  void _updateCommentById(
    String id,
    ComicCommentData Function(ComicCommentData) update,
  ) {
    List<ComicCommentData> replace(List<ComicCommentData> comments) => comments
        .map((comment) => comment.id == id ? update(comment) : comment)
        .toList();
    state.comments = replace(state.comments);
    for (final entry in state.replyComments.entries) {
      state.replyComments[entry.key] = replace(entry.value);
    }
  }

  Future<void> toggleReplies(ComicCommentData comment) async {
    final id = comment.id;
    if (_disposed || id == null) return;
    if (state.expandedReplyIds.contains(id)) {
      _update(() => state.expandedReplyIds.remove(id));
      return;
    }
    _update(() => state.expandedReplyIds.add(id));
    if (state.replyComments[id]?.isNotEmpty == true) return;
    await _loadReplies(id, page: 1);
  }

  Future<void> loadMoreReplies(String id) =>
      _loadReplies(id, page: (state.replyPages[id] ?? 0) + 1);

  Future<void> _loadReplies(String id, {required int page}) async {
    if (_disposed || state.loadingReplyIds.contains(id)) return;
    final epoch = state.loadEpoch;
    _update(() => state.loadingReplyIds.add(id));
    try {
      final result = await _loadPage(page, replyTo: id);
      if (!_isCurrent(epoch)) return;
      _update(() {
        final existing = page == 1
            ? const <ComicCommentData>[]
            : (state.replyComments[id] ?? const <ComicCommentData>[]);
        state.replyComments[id] = sortRepliesChronologically(
          _mergeComments(existing, result.comments),
        );
        state.replyPages[id] = page;
        state.replyMaxPages[id] = result.maxPage;
        state.replyHasMore[id] = _hasMore(
          page,
          result.comments.length,
          result.maxPage,
        );
      });
    } finally {
      _update(() => state.loadingReplyIds.remove(id));
    }
  }

  bool canSubmitComment(String text) =>
      !_disposed &&
      text.trim().isNotEmpty &&
      !state.sendingComment &&
      isLogged &&
      supportCommentSend;

  Future<void> submitComment(String content) async {
    final text = content.trim();
    if (_disposed || text.isEmpty || state.sendingComment) return;
    if (!isLogged) {
      _emit(CommentsEffectType.loginRequired);
      return;
    }
    if (!supportCommentSend) {
      _emit(CommentsEffectType.sendUnsupported);
      return;
    }
    final replyTo = state.replyToComment?.id;
    _update(() => state.sendingComment = true);
    try {
      await _sourceService.sendComment(
        comicId: comicId,
        subId: subId,
        chapterId: chapterId,
        sourceKey: sourceKey,
        content: text,
        replyTo: replyTo,
      );
      if (_disposed) return;
      _update(() => state.replyToComment = null);
      _emit(CommentsEffectType.sendSucceeded);
      await loadInitial();
    } catch (error) {
      _emit(CommentsEffectType.sendFailed, error: error);
    } finally {
      _update(() => state.sendingComment = false);
    }
  }

  void _onFilterChanged() {
    if (_disposed) return;
    notifyListeners();
    _maybeLoadMoreForHiddenFilter();
  }

  void _maybeLoadMoreForHiddenFilter() {
    if (_disposed ||
        !filterModeIsHide ||
        state.initialLoading ||
        state.loadingMore ||
        !state.hasMore ||
        state.hideFilterLoadMoreQueued) {
      return;
    }
    final visibleCount = visibleComments(state.comments).length;
    if (visibleCount >= pageSize || visibleCount == state.comments.length) {
      return;
    }
    state.hideFilterLoadMoreQueued = true;
    unawaited(_loadHiddenFilterPages());
  }

  Future<void> _loadHiddenFilterPages() async {
    try {
      while (!_disposed && state.hasMore && !state.initialLoading) {
        final previousPage = state.currentPage;
        await loadMore();
        if (_disposed ||
            state.currentPage == previousPage ||
            !filterModeIsHide) {
          return;
        }
        if (visibleComments(state.comments).length >= pageSize) return;
      }
    } finally {
      if (!_disposed) state.hideFilterLoadMoreQueued = false;
    }
  }

  bool _hasMore(int page, int fetchedCount, int? maxPage) =>
      maxPage != null ? page < maxPage : fetchedCount >= pageSize;

  List<ComicCommentData> _mergeComments(
    List<ComicCommentData> existing,
    List<ComicCommentData> incoming,
  ) {
    final merged = <String, ComicCommentData>{};
    for (final comment in [...existing, ...incoming]) {
      final key =
          comment.id ??
          '${comment.userName}|${comment.time}|${comment.content}';
      merged[key] = comment;
    }
    return merged.values.toList();
  }

  bool get filterModeIsHide => _filterService.mode == CommentFilterMode.hide;

  bool isCollapsedComment(String content) =>
      _filterService.mode == CommentFilterMode.collapse &&
      _filterService.isFiltered(commentFilterText(content));

  List<ComicCommentData> visibleComments(List<ComicCommentData> all) {
    if (!filterModeIsHide) return all;
    return all
        .where((c) => !_filterService.isFiltered(commentFilterText(c.content)))
        .toList();
  }

  void _logEvent(
    String title, {
    String level = 'info',
    Map<String, Object?>? content,
  }) {
    log(
      title,
      level: level,
      source: logSource,
      content: {
        ...logContext,
        'comicId': comicId,
        'subId': subId,
        'currentPage': state.currentPage,
        'commentCount': state.comments.length,
        'hasMore': state.hasMore,
        ...?content,
      },
    );
  }

  void log(
    String title, {
    String level = 'info',
    Object? content,
    String source = 'app',
  }) {
    _sourceService.addApplicationLog(
      level: level,
      title: title,
      content: content,
      source: source,
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _filterService.removeListener(_onFilterChanged);
    // Keep cached content for the next surface, but release this surface's work.
    state.loadEpoch++;
    state.initialLoading = !state.initialLoadSucceeded;
    state.loadingMore = false;
    state.sendingComment = false;
    state.hideFilterLoadMoreQueued = false;
    state.likingCommentIds.clear();
    state.loadingReplyIds.clear();
    unawaited(_effects.close());
    super.dispose();
  }
}
