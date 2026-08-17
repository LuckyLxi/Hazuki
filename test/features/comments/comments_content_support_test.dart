import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/comments/support/comments_content_support.dart';
import 'package:hazuki/models/hazuki_models.dart';

ComicCommentData _comment(String id, String time) =>
    ComicCommentData(id: id, avatar: '', userName: id, time: time, content: '');

void main() {
  test('formats ISO-8601 comment times in the local timezone', () {
    final expected = DateTime.parse(
      '2026-07-27T17:28:58.624Z',
    ).toLocal().toString().substring(0, 16).replaceFirst('T', ' ');

    expect(formatCommentTime('2026-07-27T17:28:58.624Z'), expected);
    expect(formatCommentTime('yesterday'), 'yesterday');
  });

  test('parses legacy reply attribution with arbitrary whitespace', () {
    expect(parseCommentUserAttribution('Alice  👉  Bob'), (
      author: 'Alice',
      replyTo: 'Bob',
    ));
    expect(parseCommentUserAttribution('Alice👉Bob'), (
      author: 'Alice',
      replyTo: 'Bob',
    ));
    expect(parseCommentUserAttribution('Alice'), (
      author: 'Alice',
      replyTo: null,
    ));
  });

  test('sorts replies chronologically and keeps undated replies last', () {
    final sorted = sortRepliesChronologically([
      _comment('newest', '2026-07-27T17:28:58.624Z'),
      _comment('unknown', 'just now'),
      _comment('oldest', '2026-07-26T17:28:58.624Z'),
    ]);

    expect(sorted.map((comment) => comment.id), [
      'oldest',
      'newest',
      'unknown',
    ]);
  });
}
