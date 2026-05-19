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

  ComicCommentData copyWith({
    String? avatar,
    String? userName,
    String? time,
    String? content,
    String? id,
    int? replyCount,
    bool? isLiked,
    int? score,
    int? voteStatus,
  }) {
    return ComicCommentData(
      avatar: avatar ?? this.avatar,
      userName: userName ?? this.userName,
      time: time ?? this.time,
      content: content ?? this.content,
      id: id ?? this.id,
      replyCount: replyCount ?? this.replyCount,
      isLiked: isLiked ?? this.isLiked,
      score: score ?? this.score,
      voteStatus: voteStatus ?? this.voteStatus,
    );
  }
}

class ComicCommentsPageResult {
  const ComicCommentsPageResult({
    required this.comments,
    required this.maxPage,
  });

  final List<ComicCommentData> comments;
  final int? maxPage;
}
