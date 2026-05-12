import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/comment_filter_service.dart';
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

    test('empty / whitespace-only user keyword does not match', () async {
      await service.save(
        userKeywords: ['', '   ', '\n\n'],
        mode: CommentFilterMode.collapse,
      );
      expect(service.isFiltered('anything'), isFalse);
    });
  });

  group('CommentFilterService persistence', () {
    test('load reads stored keywords and mode from SharedPreferences',
        () async {
      SharedPreferences.setMockInitialValues({
        'comment_filter_keywords': const ['abc', 'def'],
        'comment_filter_mode': 'hide',
      });
      final service = CommentFilterService();
      await service.load();
      expect(service.userKeywords, ['abc', 'def']);
      expect(service.mode, CommentFilterMode.hide);
    });

    test('save round-trips through SharedPreferences', () async {
      SharedPreferences.setMockInitialValues(const {});
      final a = CommentFilterService();
      await a.load();
      await a.save(
        userKeywords: ['kw1', 'kw2'],
        mode: CommentFilterMode.hide,
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
      await service.save(
        userKeywords: ['x'],
        mode: CommentFilterMode.collapse,
      );
      expect(() => service.userKeywords.add('y'), throwsUnsupportedError);
    });
  });
}
