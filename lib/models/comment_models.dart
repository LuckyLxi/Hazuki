class ComicCommentData {
  const ComicCommentData({
    required this.avatar,
    required this.userName,
    required this.time,
    required this.content,
    this.id,
    this.replyCount,
    this.isLiked,
    this.score,
    this.voteStatus,
  });

  final String avatar;
  final String userName;
  final String time;
  final String content;
  final String? id;
  final int? replyCount;
  final bool? isLiked;
  final int? score;
  final int? voteStatus;
}

class ComicCommentsPageResult {
  const ComicCommentsPageResult({
    required this.comments,
    required this.maxPage,
  });

  final List<ComicCommentData> comments;
  final int? maxPage;
}
