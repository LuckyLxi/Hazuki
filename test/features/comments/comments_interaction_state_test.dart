import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/comments/state/comments_page_controller.dart';

void main() {
  test('interaction state owns pagination and reply collections', () {
    final state = CommentsInteractionState();

    expect(state.initialLoading, isTrue);
    expect(state.currentPage, 1);
    expect(state.replyComments, isEmpty);

    state
      ..initialLoading = false
      ..currentPage = 3
      ..sendingComment = true;
    state.expandedReplyIds.add('comment-1');

    expect(state.initialLoading, isFalse);
    expect(state.currentPage, 3);
    expect(state.sendingComment, isTrue);
    expect(state.expandedReplyIds, {'comment-1'});
  });
}
