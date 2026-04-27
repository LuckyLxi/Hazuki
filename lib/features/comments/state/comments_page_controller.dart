import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/hazuki_source_service.dart';

class CommentsPageController {
  CommentsPageController({HazukiSourceService? sourceService})
    : _sourceService = sourceService ?? HazukiSourceService.instance;

  final HazukiSourceService _sourceService;

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
}
