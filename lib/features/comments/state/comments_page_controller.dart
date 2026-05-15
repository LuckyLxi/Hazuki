import 'package:flutter/foundation.dart';
import 'package:hazuki/features/comments/support/comments_content_support.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/comment_filter_service.dart';
import 'package:hazuki/services/hazuki_source_service.dart';

class CommentsPageController {
  CommentsPageController({
    required HazukiSourceService sourceService,
    required CommentFilterService filterService,
  }) : _sourceService = sourceService,
       _filterService = filterService;

  final HazukiSourceService _sourceService;
  final CommentFilterService _filterService;

  bool isLogged(String sourceKey) => sourceKey.trim().isEmpty
      ? _sourceService.isLogged
      : _sourceService.isLoggedForSource(sourceKey);

  bool supportCommentSend(String sourceKey) => sourceKey.trim().isEmpty
      ? _sourceService.supportCommentSend
      : _sourceService.supportCommentSendForSource(sourceKey);

  Future<ComicCommentsPageResult> loadCommentsPage({
    required String comicId,
    String? subId,
    String sourceKey = '',
    required int page,
    required int pageSize,
    required Duration timeout,
  }) {
    return _sourceService
        .loadCommentsPage(
          comicId: comicId,
          subId: subId,
          sourceKey: sourceKey,
          page: page,
          pageSize: pageSize,
        )
        .timeout(timeout);
  }

  Future<void> sendComment({
    required String comicId,
    String? subId,
    String sourceKey = '',
    required String content,
    String? replyTo,
  }) {
    return _sourceService.sendComment(
      comicId: comicId,
      subId: subId,
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
