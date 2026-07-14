import 'dart:convert';

import '../../../models/hazuki_models.dart';
import '../account/source_relogin_coordinator.dart';
import '../common/source_json_coerce.dart';
import '../models/source_identity.dart';
import '../runtime/source_runtime_facade.dart';
import '../runtime/source_runtime_host.dart';

class SourceCommentsCapability {
  SourceCommentsCapability({
    required SourceRuntimeHost runtimeHost,
    required SourceReloginCoordinator reloginCoordinator,
  }) : _runtimeHost = runtimeHost,
       _reloginCoordinator = reloginCoordinator;

  final SourceRuntimeHost _runtimeHost;
  final SourceReloginCoordinator _reloginCoordinator;

  String _resolveSourceKey(String sourceKey) => sourceKey.trim().isEmpty
      ? _runtimeHost.activeSourceKey
      : _runtimeHost.normalize(sourceKey);

  HazukiSourceFacade _facadeFor(String sourceKey) =>
      _runtimeHost.handleFor(_resolveSourceKey(sourceKey)).facade;

  Future<T> _runWithReloginRetry<T>(
    Future<T> Function() action, {
    required HazukiSourceFacade facade,
  }) => _reloginCoordinator.runWithReloginRetry(
    action,
    context: SourceFacadeReloginContext(facade),
  );

  Future<ComicCommentsPageResult> loadCommentsPage({
    required String comicId,
    String? subId,
    String? chapterId,
    String sourceKey = '',
    int page = 1,
    int pageSize = 16,
    String? replyTo,
  }) async {
    final facade = _facadeFor(sourceKey);
    await facade.ensureInitialized();

    final engine = facade.js.engine;
    if (engine == null) {
      throw Exception('source_not_initialized');
    }

    final subIdArg = subId == null ? 'null' : jsonEncode(subId);
    final replyToArg = replyTo == null ? 'null' : jsonEncode(replyTo);
    final chapterIdArg = chapterId == null ? 'null' : jsonEncode(chapterId);
    final hasChapterComments =
        chapterId?.isNotEmpty == true &&
        facade.js.asBool(
          facade.js.evaluate(
            '!!this.__hazuki_source.comic?.loadChapterComments',
          ),
        );
    final dynamic result = engine.evaluate(
      hasChapterComments
          ? 'this.__hazuki_source.comic.loadChapterComments(${jsonEncode(comicId)}, $chapterIdArg, $page, $replyToArg)'
          : 'this.__hazuki_source.comic.loadComments(${jsonEncode(comicId)}, $subIdArg, $page, $replyToArg)',
      name: 'source_comments.js',
    );
    final dynamic resolved = await facade.js.resolve(result);
    if (resolved is! Map) {
      return const ComicCommentsPageResult(comments: [], maxPage: null);
    }

    final resultMap = Map<String, dynamic>.from(resolved);
    final commentsRaw = resultMap['comments'];
    if (commentsRaw is! List) {
      return ComicCommentsPageResult(
        comments: const [],
        maxPage: jsAsInt(resultMap['maxPage']),
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
        replyCount: jsAsInt(map['replyCount']),
        isLiked: map['isLiked'] is bool ? map['isLiked'] as bool : null,
        score: jsAsInt(map['score']),
        voteStatus: jsAsInt(map['voteStatus']),
      );
    }).toList();

    final comments = (pageSize <= 0 || all.length <= pageSize)
        ? all
        : all.sublist(0, pageSize);

    return ComicCommentsPageResult(
      comments: comments,
      maxPage: jsAsInt(resultMap['maxPage']),
    );
  }

  Future<List<ComicCommentData>> loadComments({
    required String comicId,
    String? subId,
    String? chapterId,
    String sourceKey = '',
    int page = 1,
    int pageSize = 16,
    String? replyTo,
  }) async {
    final result = await loadCommentsPage(
      comicId: comicId,
      subId: subId,
      chapterId: chapterId,
      sourceKey: sourceKey,
      page: page,
      pageSize: pageSize,
      replyTo: replyTo,
    );
    return result.comments;
  }

  Future<void> sendComment({
    required String comicId,
    String? subId,
    String? chapterId,
    String sourceKey = '',
    required String content,
    String? replyTo,
  }) async {
    final facade = _facadeFor(sourceKey);
    await facade.ensureInitialized();

    final engine = facade.js.engine;
    if (engine == null) {
      throw Exception('source_not_initialized');
    }

    final text = content.trim();
    if (text.isEmpty) {
      throw Exception('comment_content_empty');
    }

    final subIdArg = subId == null ? 'null' : jsonEncode(subId);
    final chapterIdArg = chapterId == null ? 'null' : jsonEncode(chapterId);
    final replyToArg = replyTo == null ? 'null' : jsonEncode(replyTo);

    Future<void> runSend() async {
      final hasChapterComments =
          chapterId?.isNotEmpty == true &&
          facade.js.asBool(
            facade.js.evaluate(
              '!!this.__hazuki_source.comic?.sendChapterComment',
            ),
          );
      final dynamic result = engine.evaluate(
        hasChapterComments
            ? 'this.__hazuki_source.comic.sendChapterComment(${jsonEncode(comicId)}, $chapterIdArg, ${jsonEncode(text)}, $replyToArg)'
            : 'this.__hazuki_source.comic.sendComment(${jsonEncode(comicId)}, $subIdArg, ${jsonEncode(text)}, $replyToArg)',
        name: 'source_send_comment.js',
      );
      await facade.js.resolve(result);
    }

    await _runWithReloginRetry(runSend, facade: facade);
  }

  Future<void> likeComment({
    required String comicId,
    String? subId,
    String sourceKey = '',
    required String commentId,
    required bool isLike,
  }) async {
    final facade = _facadeFor(sourceKey);
    await facade.ensureInitialized();

    final engine = facade.js.engine;
    if (engine == null) {
      throw Exception('source_not_initialized');
    }

    final subIdArg = subId == null ? 'null' : jsonEncode(subId);

    Future<void> runLike() async {
      final dynamic result = engine.evaluate(
        'this.__hazuki_source.comic.likeComment(${jsonEncode(comicId)}, $subIdArg, ${jsonEncode(commentId)}, $isLike)',
        name: 'source_like_comment.js',
      );
      await facade.js.resolve(result);
    }

    await _runWithReloginRetry(runLike, facade: facade);
  }

  bool supportCommentSendForSource(String sourceKey) {
    final facade = _facadeFor(sourceKey);
    final engine = facade.js.engine;
    if (engine == null) {
      return false;
    }
    return facade.js.asBool(
      facade.js.evaluate('!!this.__hazuki_source.comic?.sendComment'),
    );
  }

  bool supportCommentLikeForSource(String sourceKey) {
    final facade = _facadeFor(sourceKey);
    final engine = facade.js.engine;
    if (engine == null) {
      return false;
    }
    return facade.js.asBool(
      facade.js.evaluate('!!this.__hazuki_source.comic?.likeComment'),
    );
  }

  bool supportCommentRepliesForSource(String sourceKey) {
    final resolvedSourceKey = _resolveSourceKey(sourceKey);
    if (!isHazukiPicacgSourceKey(resolvedSourceKey) &&
        !isHazukiCopyMangaSourceKey(resolvedSourceKey)) {
      return false;
    }
    final facade = _runtimeHost.handleFor(resolvedSourceKey).facade;
    final engine = facade.js.engine;
    if (engine == null) {
      return false;
    }
    return facade.js.asBool(
      facade.js.evaluate('!!this.__hazuki_source.comic?.loadComments'),
    );
  }
}
