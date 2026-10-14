import '../support/source_catalog_fixtures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/app/app_preferences.dart';
import 'package:hazuki/features/comments/state/comments_page_controller.dart';
import 'package:hazuki/features/comments/support/comments_content_support.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/comment_filter_service.dart';
import 'package:hazuki/services/comment_filter/comment_filter_sync_store.dart';
import 'package:hazuki/services/source/runtime/source_runtime_assembly.dart';
import 'package:hazuki/services/source/adapters/hazuki_source_content_adapters.dart';
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

    test('does not filter without user keywords', () {
      expect(service.isFiltered('快看免费发个传送门'), isFalse);
      expect(service.isFiltered('已去广告 链接见头像'), isFalse);
    });

    test('does not match unrelated content', () {
      expect(service.isFiltered('这本漫画真好看'), isFalse);
    });

    test('ignores invisible characters injected between characters', () async {
      await service.save(
        userKeywords: ['免费发个'],
        mode: CommentFilterMode.collapse,
      );
      // U+200B zero-width space inserted between every character.
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

  group('CommentFilterService sync persistence', () {
    late CommentFilterService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        hazukiCommentFilterKeywordsKey: ['local'],
        hazukiCommentFilterKeywordsUpdatedAtKey: 100,
        hazukiCommentFilterModeKey: 'hide',
      });
      service = CommentFilterService();
      addTearDown(service.dispose);
      await service.load();
    });

    test(
      'captures stored edits rather than stale in-memory keywords',
      () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList(hazukiCommentFilterKeywordsKey, ['external']);
        await prefs.setInt(hazukiCommentFilterKeywordsUpdatedAtKey, 200);
        final snapshot = await service.captureMergeSnapshot();
        expect(snapshot.keywords, ['external']);
        expect(snapshot.updatedAtMs, 200);
        expect(service.userKeywords, ['local']);
      },
    );

    test('keeps merged timestamp and notifies only after reloading', () async {
      final observed = <(List<String>, CommentFilterMode)>[];
      service.addListener(
        () => observed.add((service.userKeywords, service.mode)),
      );
      await service.applyMergedKeywords(
        const CommentFilterMergeSnapshot(
          keywords: ['remote'],
          updatedAtMs: 200,
        ),
      );
      await service.applySyncedPreferences({
        hazukiCommentFilterModeKey: 'collapse',
      });
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(hazukiCommentFilterKeywordsUpdatedAtKey), 200);
      expect(service.userKeywords, ['local']);
      expect(observed, isEmpty);
      await service.reloadAfterExternalChange();
      expect(observed, hasLength(1));
      expect(observed.single.$1, ['remote']);
      expect(observed.single.$2, CommentFilterMode.collapse);
    });

    test('legacy merge removes the timestamp and preserves mode', () async {
      await service.applyMergedKeywords(
        const CommentFilterMergeSnapshot(keywords: [], updatedAtMs: 0),
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(hazukiCommentFilterKeywordsKey), isEmpty);
      expect(
        prefs.containsKey(hazukiCommentFilterKeywordsUpdatedAtKey),
        isFalse,
      );
      expect(prefs.getString(hazukiCommentFilterModeKey), 'hide');
    });

    test('patch preserves absent keys and removes explicit nulls', () async {
      await service.applySyncedPreferences({hazukiCommentFilterModeKey: null});
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(hazukiCommentFilterKeywordsKey), ['local']);
      expect(prefs.getInt(hazukiCommentFilterKeywordsUpdatedAtKey), 100);
      expect(prefs.containsKey(hazukiCommentFilterModeKey), isFalse);
    });

    test(
      'patch keeps preference conversions and ignores unrelated keys',
      () async {
        final prefs = await SharedPreferences.getInstance();
        await service.applySyncedPreferences({
          hazukiCommentFilterKeywordsKey: [1, true, 'remote'],
          'unrelated_setting': 'ignored',
        });
        expect(prefs.getStringList(hazukiCommentFilterKeywordsKey), [
          '1',
          'true',
          'remote',
        ]);
        expect(prefs.containsKey('unrelated_setting'), isFalse);
        final unknown = {'mode': 'custom'};
        await service.applySyncedPreferences({
          hazukiCommentFilterModeKey: unknown,
        });
        expect(prefs.getString(hazukiCommentFilterModeKey), 'hide');
        await service.applySyncedPreferences({
          hazukiCommentFilterModeKey: unknown,
        }, stringifyUnknown: true);
        expect(prefs.getString(hazukiCommentFilterModeKey), unknown.toString());
      },
    );
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
        comicId: 'comic',
        sourceService: (() {
          final source = SourceRuntimeAssembly(
            initialCatalog: hazukiAllowedSourceCatalog,
          );
          return HazukiSourceCommentsAdapter(
            comments: source.testing.comments,
            debug: source.testing.debug,
          );
        })(),
        filterService: service,
      );
      addTearDown(controller.dispose);
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
        comicId: 'comic',
        sourceService: (() {
          final source = SourceRuntimeAssembly(
            initialCatalog: hazukiAllowedSourceCatalog,
          );
          return HazukiSourceCommentsAdapter(
            comments: source.testing.comments,
            debug: source.testing.debug,
          );
        })(),
        filterService: service,
      );
      addTearDown(controller.dispose);
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
