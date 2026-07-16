import '../../../models/hazuki_models.dart';
import '../account/source_account_operations.dart';
import 'comments_capability.dart';

/// Comment operations consumed by the comments gateway.
class SourceCommentsOperations {
  const SourceCommentsOperations({
    required SourceCommentsCapability comments,
    required SourceAccountOperations account,
  }) : _comments = comments,
       _account = account;

  final SourceCommentsCapability _comments;
  final SourceAccountOperations _account;

  bool get isLogged => _account.isLogged;
  bool get supportCommentSend => _comments.supportCommentSendForSource('');
  bool get supportCommentLike => _comments.supportCommentLikeForSource('');

  bool isLoggedForSource(String sourceKey) =>
      _account.isLoggedForSource(sourceKey);

  bool supportCommentSendForSource(String sourceKey) =>
      _comments.supportCommentSendForSource(sourceKey);

  bool supportCommentLikeForSource(String sourceKey) =>
      _comments.supportCommentLikeForSource(sourceKey);

  bool supportCommentRepliesForSource(String sourceKey) =>
      _comments.supportCommentRepliesForSource(sourceKey);

  Future<ComicCommentsPageResult> loadCommentsPage({
    required String comicId,
    String? subId,
    String? chapterId,
    String sourceKey = '',
    int page = 1,
    int pageSize = 16,
    String? replyTo,
  }) => _comments.loadCommentsPage(
    comicId: comicId,
    subId: subId,
    chapterId: chapterId,
    sourceKey: sourceKey,
    page: page,
    pageSize: pageSize,
    replyTo: replyTo,
  );

  Future<void> sendComment({
    required String comicId,
    String? subId,
    String? chapterId,
    String sourceKey = '',
    required String content,
    String? replyTo,
  }) => _comments.sendComment(
    comicId: comicId,
    subId: subId,
    chapterId: chapterId,
    sourceKey: sourceKey,
    content: content,
    replyTo: replyTo,
  );

  Future<void> likeComment({
    required String comicId,
    String? subId,
    String sourceKey = '',
    required String commentId,
    required bool isLike,
  }) => _comments.likeComment(
    comicId: comicId,
    subId: subId,
    sourceKey: sourceKey,
    commentId: commentId,
    isLike: isLike,
  );
}
