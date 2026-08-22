import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/comments/view/comments_page.dart';

void main() {
  group('resolveCommentsSafeBottomInset', () {
    test('keeps the last inset while another route covers comments', () {
      expect(
        resolveCommentsSafeBottomInset(
          observedSafeBottom: 0,
          lastCurrentRouteSafeBottom: 24,
          routeIsCurrent: false,
          preserveAfterRouteCover: true,
        ),
        24,
      );
    });

    test('keeps the last inset while system UI restores after pop', () {
      expect(
        resolveCommentsSafeBottomInset(
          observedSafeBottom: 0,
          lastCurrentRouteSafeBottom: 24,
          routeIsCurrent: true,
          preserveAfterRouteCover: true,
        ),
        24,
      );
    });

    test('uses the observed inset while comments route is current', () {
      expect(
        resolveCommentsSafeBottomInset(
          observedSafeBottom: 16,
          lastCurrentRouteSafeBottom: 24,
          routeIsCurrent: true,
          preserveAfterRouteCover: false,
        ),
        16,
      );
    });

    test('uses the observed inset when there is no cached value', () {
      expect(
        resolveCommentsSafeBottomInset(
          observedSafeBottom: 12,
          lastCurrentRouteSafeBottom: null,
          routeIsCurrent: false,
          preserveAfterRouteCover: true,
        ),
        12,
      );
    });
  });
}
