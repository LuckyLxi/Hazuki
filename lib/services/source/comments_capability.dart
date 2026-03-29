part of '../hazuki_source_service.dart';

extension HazukiSourceServiceCommentsCapability on HazukiSourceService {
  Future<ComicCommentsPageResult> loadCommentsPage({
    required String comicId,
    String? subId,
    int page = 1,
    int pageSize = 16,
    String? replyTo,
  }) async {
    final engine = _engine;
    if (engine == null) {
      throw Exception('source_not_initialized');
    }

    final subIdArg = subId == null ? 'null' : jsonEncode(subId);
    final replyToArg = replyTo == null ? 'null' : jsonEncode(replyTo);
    final dynamic result = engine.evaluate(
      'this.__hazuki_source.comic.loadComments(${jsonEncode(comicId)}, $subIdArg, $page, $replyToArg)',
      name: 'source_comments.js',
    );
    final dynamic resolved = await _awaitJsResult(result);
    if (resolved is! Map) {
      return const ComicCommentsPageResult(comments: [], maxPage: null);
    }

    final resultMap = Map<String, dynamic>.from(resolved);
    final commentsRaw = resultMap['comments'];
    if (commentsRaw is! List) {
      return ComicCommentsPageResult(
        comments: const [],
        maxPage: _asInt(resultMap['maxPage']),
      );
    }

    final all = commentsRaw.whereType<Map>().map((e) {
      final map = Map<String, dynamic>.from(e);
      return ComicCommentData(
        avatar: map['avatar']?.toString() ?? '',
        userName: map['userName']?.toString() ?? '',
        time: map['time']?.toString() ?? '',
        content: map['content']?.toString() ?? '',
        id: map['id']?.toString() ?? map['commentId']?.toString(),
        replyCount: _asInt(map['replyCount']),
        isLiked: map['isLiked'] is bool ? map['isLiked'] as bool : null,
        score: _asInt(map['score']),
        voteStatus: _asInt(map['voteStatus']),
      );
    }).toList();

    final comments = (pageSize <= 0 || all.length <= pageSize)
        ? all
        : all.sublist(0, pageSize);

    return ComicCommentsPageResult(
      comments: comments,
      maxPage: _asInt(resultMap['maxPage']),
    );
  }

  Future<List<ComicCommentData>> loadComments({
    required String comicId,
    String? subId,
    int page = 1,
    int pageSize = 16,
    String? replyTo,
  }) async {
    final result = await loadCommentsPage(
      comicId: comicId,
      subId: subId,
      page: page,
      pageSize: pageSize,
      replyTo: replyTo,
    );
    return result.comments;
  }

  Future<void> sendComment({
    required String comicId,
    String? subId,
    required String content,
    String? replyTo,
  }) async {
    final engine = _engine;
    if (engine == null) {
      throw Exception('source_not_initialized');
    }

    final text = content.trim();
    if (text.isEmpty) {
      throw Exception('comment_content_empty');
    }

    final subIdArg = subId == null ? 'null' : jsonEncode(subId);
    final replyToArg = replyTo == null ? 'null' : jsonEncode(replyTo);

    await _runWithReloginRetry(() async {
      final dynamic result = engine.evaluate(
        'this.__hazuki_source.comic.sendComment(${jsonEncode(comicId)}, $subIdArg, ${jsonEncode(text)}, $replyToArg)',
        name: 'source_send_comment.js',
      );
      await _awaitJsResult(result);
    });
  }
}
