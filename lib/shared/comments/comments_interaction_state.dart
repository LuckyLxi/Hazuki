import 'package:hazuki/models/hazuki_models.dart';

/// Mutable comments interaction state shared by embedded comments surfaces.
///
/// It is owned by [CommentsPageController], while widgets retain ownership of
/// Flutter-only objects such as focus and scrolling.
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
