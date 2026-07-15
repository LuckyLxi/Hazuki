import 'package:flutter/foundation.dart';
import 'package:hazuki/features/comments/support/comments_content_support.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/comment_filter_service.dart';
import 'package:hazuki/services/source/source_capabilities.dart';

class CommentsPageController {
  CommentsPageController({
    required SourceCommentsGateway sourceService,
    required CommentFilterService filterService,
    CommentsInteractionState? state,
  }) : _sourceService = sourceService,
       _filterService = filterService,
       state = state ?? CommentsInteractionState();

  final CommentsInteractionState state;

  final SourceCommentsGateway _sourceService;
  final CommentFilterService _filterService;

  bool isLogged(String sourceKey) => sourceKey.trim().isEmpty
      ? _sourceService.isLogged
      : _sourceService.isLoggedForSource(sourceKey);

  bool supportCommentSend(String sourceKey) => sourceKey.trim().isEmpty
      ? _sourceService.supportCommentSend
      : _sourceService.supportCommentSendForSource(sourceKey);

  bool supportCommentLike(String sourceKey) => sourceKey.trim().isEmpty
      ? _sourceService.supportCommentLike
      : _sourceService.supportCommentLikeForSource(sourceKey);

  bool supportCommentReplies(String sourceKey) => sourceKey.trim().isEmpty
      ? _sourceService.supportCommentRepliesForSource(sourceKey)
      : _sourceService.supportCommentRepliesForSource(sourceKey);

  Future<ComicCommentsPageResult> loadCommentsPage({
    required String comicId,
    String? subId,
    String? chapterId,
    String sourceKey = '',
    required int page,
    required int pageSize,
    required Duration timeout,
    String? replyTo,
  }) {
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
        .timeout(timeout);
  }

  Future<void> likeComment({
    required String comicId,
    String? subId,
    String sourceKey = '',
    required String commentId,
    required bool isLike,
  }) {
    return _sourceService.likeComment(
      comicId: comicId,
      subId: subId,
      sourceKey: sourceKey,
      commentId: commentId,
      isLike: isLike,
    );
  }

  Future<void> sendComment({
    required String comicId,
    String? subId,
    String? chapterId,
    String sourceKey = '',
    required String content,
    String? replyTo,
  }) {
    return _sourceService.sendComment(
      comicId: comicId,
      subId: subId,
      chapterId: chapterId,
      sourceKey: sourceKey,
      content: content,
      replyTo: replyTo,
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

  void addFilterListener(VoidCallback callback) =>
      _filterService.addListener(callback);

  void removeFilterListener(VoidCallback callback) =>
      _filterService.removeListener(callback);

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
}

/// Mutable interaction state owned by the comments controller. The widget
/// remains responsible only for Flutter objects such as focus and scrolling.
class CommentsInteractionState {
  List<ComicCommentData> comments = const [];
  String? errorMessage;
  bool initialLoading = true;
  bool initialLoadSucceeded = false;
  bool loadingMore = false;
  int loadEpoch = 0;
  bool hasMore = true;
  bool sendingComment = false;
  bool hideFilterLoadMoreQueued = false;
  bool supportCommentLike = false;
  bool supportCommentReplies = false;
  int currentPage = 1;
  int? maxPage;
  ComicCommentData? replyToComment;
  final Set<String> likingCommentIds = <String>{};
  final Set<String> expandedReplyIds = <String>{};
  final Set<String> loadingReplyIds = <String>{};
  final Map<String, List<ComicCommentData>> replyComments = {};
  final Map<String, int> replyPages = {};
  final Map<String, int?> replyMaxPages = {};
  final Map<String, bool> replyHasMore = {};
}
