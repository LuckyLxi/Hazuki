import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/app/app_preferences.dart';
import 'package:hazuki/features/comments/state/comments_page_controller.dart';
import 'package:hazuki/features/comments/support/comments_content_support.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/comment_filter_service.dart';
import 'package:hazuki/services/hazuki_source_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CommentFilterService.isFiltered', () {
    late CommentFilterService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues(const {});
      service = CommentFilterService();
      await service.load();
    });

    test('matches built-in phrases', () {
      expect(service.isFiltered('快看免费发个传送门'), isTrue);
      expect(service.isFiltered('已去广告 链接见头像'), isTrue);
    });

    test('does not match unrelated content', () {
      expect(service.isFiltered('这本漫画真好看'), isFalse);
    });

    test('ignores invisible characters injected between characters', () {
      // U+200B zero-width space inserted between every char of a builtin phrase.
      const obfuscated = '免​费​发​个';
      expect(service.isFiltered(obfuscated), isTrue);
    });

    test('matches user keyword (single line, case-insensitive)', () async {
      await service.save(
        userKeywords: ['SpamWord'],
        mode: CommentFilterMode.collapse,
      );
      expect(service.isFiltered('this contains spamword inside'), isTrue);
      expect(service.isFiltered('clean comment'), isFalse);
    });

    test('matches visible inline image alt text used by comments', () async {
      await service.save(
        userKeywords: ['blocked phrase'],
        mode: CommentFilterMode.collapse,
      );
      const content =
          '<p>safe prefix</p><img src="emoji.png" alt="blocked phrase">';
      expect(service.isFiltered(commentFilterText(content)), isTrue);
    });

    test(
      'multi-line user keyword requires every non-empty line to appear',
      () async {
        await service.save(
          userKeywords: ['line one\nline two'],
          mode: CommentFilterMode.collapse,
        );
        expect(
          service.isFiltered('preamble line one in middle line two ending'),
          isTrue,
        );
        expect(service.isFiltered('only line one is here'), isFalse);
      },
    );

    test('matches when a pasted line break is removed by the input', () async {
      const storedKeyword =
          '給大家發個蘿莉視頻破.解版，幼和禁區.視頻豐富，都不收費已經去廣告！拿走不用謝！！'
          '下栽鏈.接在我頭.像，輸入到瀏覽器就可以打開了';
      const comment =
          '給大家發個蘿莉視頻破.解版，幼和禁區.視頻豐富，都不收費已經去廣告！拿走不用謝！！\n'
          '下栽鏈.接在我頭.像，輸入到瀏覽器就可以打開了';
      await service.save(
        userKeywords: [storedKeyword],
        mode: CommentFilterMode.hide,
      );

      expect(service.isFiltered(commentFilterText(comment)), isTrue);
    });

    test('empty / whitespace-only user keyword does not match', () async {
      await service.save(
        userKeywords: ['', '   ', '\n\n'],
        mode: CommentFilterMode.collapse,
      );
      expect(service.isFiltered('anything'), isFalse);
    });
  });

  group('CommentFilterService persistence', () {
    test(
      'load reads stored keywords and mode from SharedPreferences',
      () async {
        SharedPreferences.setMockInitialValues({
          'comment_filter_keywords': const ['abc', 'def'],
          'comment_filter_mode': 'hide',
        });
        final service = CommentFilterService();
        await service.load();
        expect(service.userKeywords, ['abc', 'def']);
        expect(service.mode, CommentFilterMode.hide);
      },
    );

    test('save round-trips through SharedPreferences', () async {
      SharedPreferences.setMockInitialValues(const {});
      final a = CommentFilterService();
      await a.load();
      await a.save(userKeywords: ['kw1', 'kw2'], mode: CommentFilterMode.hide);

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getInt(hazukiCommentFilterKeywordsUpdatedAtKey),
        greaterThan(0),
      );

      final b = CommentFilterService();
      await b.load();
      expect(b.userKeywords, ['kw1', 'kw2']);
      expect(b.mode, CommentFilterMode.hide);
    });

    test('userKeywords getter returns an unmodifiable view', () async {
      SharedPreferences.setMockInitialValues(const {});
      final service = CommentFilterService();
      await service.load();
      await service.save(userKeywords: ['x'], mode: CommentFilterMode.collapse);
      expect(() => service.userKeywords.add('y'), throwsUnsupportedError);
    });
  });

  group('CommentsPageController filtering', () {
    test('collapse mode keeps filtered comments in the visible list', () async {
      SharedPreferences.setMockInitialValues(const {});
      final service = CommentFilterService();
      await service.load();
      await service.save(
        userKeywords: ['blocked'],
        mode: CommentFilterMode.collapse,
      );
      final controller = CommentsPageController(
        sourceService: HazukiSourceService(),
        filterService: service,
      );
      const comments = [
        ComicCommentData(
          avatar: '',
          userName: 'a',
          time: '',
          content: 'blocked comment',
        ),
        ComicCommentData(
          avatar: '',
          userName: 'b',
          time: '',
          content: 'clean comment',
        ),
      ];

      expect(controller.isCollapsedComment(comments.first.content), isTrue);
      expect(controller.visibleComments(comments), comments);
    });

    test('hide mode removes filtered comments from the visible list', () async {
      SharedPreferences.setMockInitialValues(const {});
      final service = CommentFilterService();
      await service.load();
      await service.save(
        userKeywords: ['blocked'],
        mode: CommentFilterMode.hide,
      );
      final controller = CommentsPageController(
        sourceService: HazukiSourceService(),
        filterService: service,
      );
      const comments = [
        ComicCommentData(
          avatar: '',
          userName: 'a',
          time: '',
          content: 'blocked comment',
        ),
        ComicCommentData(
          avatar: '',
          userName: 'b',
          time: '',
          content: 'clean comment',
        ),
      ];

      expect(controller.isCollapsedComment(comments.first.content), isFalse);
      expect(controller.visibleComments(comments), [comments.last]);
    });
  });
}
