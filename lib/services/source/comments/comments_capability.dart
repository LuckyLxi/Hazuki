import '../runtime/source_runtime_handle.dart';
import '../runtime/source_operation_context.dart';
import '../runtime/source_operation_runner.dart';
import '../models/source_task.dart';
import 'dart:convert';

import '../../../models/hazuki_models.dart';
import '../account/source_relogin_coordinator.dart';
import '../common/source_json_coerce.dart';
import '../plugins/source_sort_options.dart';
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
    SourceOperationContext operationContext,
    Future<T> Function() action, {
    required HazukiSourceFacade facade,
  }) => _reloginCoordinator.runWithReloginRetry(
    action,
    context: SourceFacadeReloginContext(facade),
    checkActive: operationContext.checkActive,
  );

  Future<ComicCommentsPageResult> loadCommentsPage({
    required String comicId,
    String? subId,
    String? chapterId,
    String sourceKey = '',
    int page = 1,
    int pageSize = 16,
    String? replyTo,
    String order = '',
    SourceTaskOrigin? taskOrigin,
  }) async => runSourceOperation(
    _runtimeHost,
    _runtimeHost.handleFor(_resolveSourceKey(sourceKey)),
    'comments.load',
    (operationContext) => _loadCommentsPageTask(
      operationContext,
      comicId: comicId,
      subId: subId,
      chapterId: chapterId,
      sourceKey: sourceKey,
      page: page,
      pageSize: pageSize,
      replyTo: replyTo,
      order: order,
    ),
    origin: taskOrigin,
    serviceOwned: false,
  );

  Future<ComicCommentsPageResult> _loadCommentsPageTask(
    SourceOperationContext operationContext, {
    required String comicId,
    String? subId,
    String? chapterId,
    String sourceKey = '',
    int page = 1,
    int pageSize = 16,
    String? replyTo,
    String order = '',
  }) async {
    final resolvedSourceKey = _resolveSourceKey(sourceKey);
    final facade = _facadeFor(resolvedSourceKey);
    return facade.handle.runOperation(() async {
      await facade.ensureInitialized();

      final engine = facade.js.engine;
      if (engine == null) {
        throw Exception('source_not_initialized');
      }

      final subIdArg = subId == null ? 'null' : jsonEncode(subId);
      final replyToArg = replyTo == null ? 'null' : jsonEncode(replyTo);
      final chapterIdArg = chapterId == null ? 'null' : jsonEncode(chapterId);
      final orderArg = jsonEncode(
        commentSortOptionsForSource(resolvedSourceKey).normalize(order),
      );
      final hasChapterComments =
          chapterId?.isNotEmpty == true &&
          facade.js.asBool(
            await operationContext.evaluate(
              engine,
              '!!this.__hazuki_source.comic?.loadChapterComments',
            ),
          );
      final dynamic result = await operationContext.evaluate(
        engine,
        hasChapterComments
            ? 'this.__hazuki_source.comic.loadChapterComments(${jsonEncode(comicId)}, $chapterIdArg, $page, $replyToArg, $orderArg)'
            : 'this.__hazuki_source.comic.loadComments(${jsonEncode(comicId)}, $subIdArg, $page, $replyToArg, $orderArg)',
        name: 'source_comments.js',
      );
      final dynamic resolved = await operationContext.resolve(
        facade.js.resolve(result),
      );
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

      ComicCommentData parseComment(Map map) => ComicCommentData(
        avatar: map['avatar']?.toString() ?? '',
        userName: map['userName']?.toString() ?? '',
        time: map['time']?.toString() ?? '',
        content: map['content']?.toString() ?? '',
        id: map['id']?.toString() ?? map['commentId']?.toString(),
        replyCount: jsAsInt(map['replyCount']),
        isLiked: map['isLiked'] is bool ? map['isLiked'] as bool : null,
        score: jsAsInt(map['score']),
        voteStatus: jsAsInt(map['voteStatus']),
        canUnlike: map['canUnlike'] != false,
      );
      final all = commentsRaw.whereType<Map>().map((map) {
        final quotes = map['quotedComments'];
        return parseComment(map).copyWith(
          quotedComments: quotes is List
              ? quotes.whereType<Map>().map(parseComment).toList()
              : const [],
        );
      }).toList();

      final comments = (pageSize <= 0 || all.length <= pageSize)
          ? all
          : all.sublist(0, pageSize);

      return ComicCommentsPageResult(
        comments: comments,
        maxPage: jsAsInt(resultMap['maxPage']),
      );
    });
  }

  Future<List<ComicCommentData>> loadComments({
    required String comicId,
    String? subId,
    String? chapterId,
    String sourceKey = '',
    int page = 1,
    int pageSize = 16,
    String? replyTo,
    String order = '',
    SourceTaskOrigin? taskOrigin,
  }) async => runSourceOperation(
    _runtimeHost,
    _runtimeHost.handleFor(_resolveSourceKey(sourceKey)),
    'comments.list',
    (operationContext) => _loadCommentsTask(
      operationContext,
      comicId: comicId,
      subId: subId,
      chapterId: chapterId,
      sourceKey: sourceKey,
      page: page,
      pageSize: pageSize,
      replyTo: replyTo,
      order: order,
    ),
    origin: taskOrigin,
    serviceOwned: false,
  );

  Future<List<ComicCommentData>> _loadCommentsTask(
    SourceOperationContext operationContext, {
    required String comicId,
    String? subId,
    String? chapterId,
    String sourceKey = '',
    int page = 1,
    int pageSize = 16,
    String? replyTo,
    String order = '',
  }) async {
    final result = await _loadCommentsPageTask(
      operationContext,
      comicId: comicId,
      subId: subId,
      chapterId: chapterId,
      sourceKey: sourceKey,
      page: page,
      pageSize: pageSize,
      replyTo: replyTo,
      order: order,
    );
    return result.comments;
  }

  SourceCommentSortOptions commentSortOptionsForSource(String sourceKey) =>
      SourceCommentSortOptions.fromPresentation(
        _runtimeHost.runtimeRegistry.presentationFor(
          _resolveSourceKey(sourceKey),
        ),
      );

  Future<void> sendComment({
    required String comicId,
    String? subId,
    String? chapterId,
    String sourceKey = '',
    required String content,
    String? replyTo,
    SourceTaskOrigin? taskOrigin,
  }) async => runSourceOperation(
    _runtimeHost,
    _runtimeHost.handleFor(_resolveSourceKey(sourceKey)),
    'comments.send',
    (operationContext) => _sendCommentTask(
      operationContext,
      comicId: comicId,
      subId: subId,
      chapterId: chapterId,
      sourceKey: sourceKey,
      content: content,
      replyTo: replyTo,
    ),
    origin: taskOrigin,
    serviceOwned: true,
    sensitiveValues: [content, comicId],
  );

  Future<void> _sendCommentTask(
    SourceOperationContext operationContext, {
    required String comicId,
    String? subId,
    String? chapterId,
    String sourceKey = '',
    required String content,
    String? replyTo,
  }) async {
    final facade = (operationContext.resource as SourceRuntimeHandle).facade;
    return facade.handle.runOperation(() async {
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
              await operationContext.evaluate(
                engine,
                '!!this.__hazuki_source.comic?.sendChapterComment',
              ),
            );
        final dynamic result = await operationContext.evaluate(
          engine,
          hasChapterComments
              ? 'this.__hazuki_source.comic.sendChapterComment(${jsonEncode(comicId)}, $chapterIdArg, ${jsonEncode(text)}, $replyToArg)'
              : 'this.__hazuki_source.comic.sendComment(${jsonEncode(comicId)}, $subIdArg, ${jsonEncode(text)}, $replyToArg)',
          name: 'source_send_comment.js',
        );
        await operationContext.resolve(facade.js.resolve(result));
      }

      await _runWithReloginRetry(operationContext, runSend, facade: facade);
    });
  }

  Future<void> likeComment({
    required String comicId,
    String? subId,
    String sourceKey = '',
    required String commentId,
    required bool isLike,
    SourceTaskOrigin? taskOrigin,
  }) async => runSourceOperation(
    _runtimeHost,
    _runtimeHost.handleFor(_resolveSourceKey(sourceKey)),
    'comments.like',
    (operationContext) => _likeCommentTask(
      operationContext,
      comicId: comicId,
      subId: subId,
      sourceKey: sourceKey,
      commentId: commentId,
      isLike: isLike,
    ),
    origin: taskOrigin,
    serviceOwned: true,
    sensitiveValues: [comicId, commentId],
  );

  Future<void> _likeCommentTask(
    SourceOperationContext operationContext, {
    required String comicId,
    String? subId,
    String sourceKey = '',
    required String commentId,
    required bool isLike,
  }) async {
    final facade = (operationContext.resource as SourceRuntimeHandle).facade;
    return facade.handle.runOperation(() async {
      await facade.ensureInitialized();

      final engine = facade.js.engine;
      if (engine == null) {
        throw Exception('source_not_initialized');
      }

      final subIdArg = subId == null ? 'null' : jsonEncode(subId);

      Future<void> runLike() async {
        final dynamic result = await operationContext.evaluate(
          engine,
          'this.__hazuki_source.comic.likeComment(${jsonEncode(comicId)}, $subIdArg, ${jsonEncode(commentId)}, $isLike)',
          name: 'source_like_comment.js',
        );
        await operationContext.resolve(facade.js.resolve(result));
      }

      await _runWithReloginRetry(operationContext, runLike, facade: facade);
    });
  }

  bool supportCommentSendForSource(String sourceKey) {
    final facade = _facadeFor(sourceKey);
    final engine = facade.js.engine;
    if (engine == null) {
      return false;
    }
    return facade.js.asBool(
      facade.js.cachedValue('!!this.__hazuki_source.comic?.sendComment'),
    );
  }

  bool supportCommentLikeForSource(String sourceKey) {
    final facade = _facadeFor(sourceKey);
    final engine = facade.js.engine;
    if (engine == null) {
      return false;
    }
    return facade.js.asBool(
      facade.js.cachedValue('!!this.__hazuki_source.comic?.likeComment'),
    );
  }

  bool supportCommentRepliesForSource(String sourceKey) {
    final resolvedSourceKey = _resolveSourceKey(sourceKey);
    final facade = _runtimeHost.handleFor(resolvedSourceKey).facade;
    final engine = facade.js.engine;
    if (engine == null) {
      return false;
    }
    return facade.js.asBool(
      facade.js.cachedValue(
        '!!this.__hazuki_source.comic?.loadComments && this.__hazuki_source.presentation?.commentReplies == true',
      ),
    );
  }
}
