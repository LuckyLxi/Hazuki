import 'package:flutter/foundation.dart';
import 'package:hazuki/features/comments/support/comments_content_support.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/comment_filter_service.dart';
import 'package:hazuki/services/hazuki_source_service.dart';

class CommentsPageController {
  CommentsPageController({
    HazukiSourceService? sourceService,
    CommentFilterService? filterService,
  }) : _sourceService = sourceService ?? HazukiSourceService.instance,
       _filterService = filterService ?? CommentFilterService.instance;

  final HazukiSourceService _sourceService;
  final CommentFilterService _filterService;

  bool get isLogged => _sourceService.isLogged;
  bool get supportCommentSend => _sourceService.supportCommentSend;

  Future<ComicCommentsPageResult> loadCommentsPage({
    required String comicId,
    String? subId,
    required int page,
    required int pageSize,
    required Duration timeout,
  }) {
    return _sourceService
        .loadCommentsPage(
          comicId: comicId,
          subId: subId,
          page: page,
          pageSize: pageSize,
        )
        .timeout(timeout);
  }

  Future<void> sendComment({
    required String comicId,
    String? subId,
    required String content,
    String? replyTo,
  }) {
    return _sourceService.sendComment(
      comicId: comicId,
      subId: subId,
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
      _filterService.isFiltered(normalizeCommentText(content));

  List<ComicCommentData> visibleComments(List<ComicCommentData> all) {
    if (!filterModeIsHide) return all;
    return all
        .where(
          (c) => !_filterService.isFiltered(normalizeCommentText(c.content)),
        )
        .toList();
  }
}
