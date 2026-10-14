import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hazuki/shared/preferences/hazuki_preference_keys.dart';
import 'comment_filter/comment_filter_sync_store.dart';

enum CommentFilterMode { collapse, hide }

class CommentFilterService
    with ChangeNotifier
    implements CommentFilterSyncStore {
  CommentFilterService();

  List<String> _userKeywords = [];
  CommentFilterMode _mode = CommentFilterMode.collapse;

  List<String> get userKeywords => List.unmodifiable(_userKeywords);
  CommentFilterMode get mode => _mode;

  Future<void> load({bool notify = false}) async {
    final prefs = await SharedPreferences.getInstance();
    _userKeywords = prefs.getStringList(hazukiCommentFilterKeywordsKey) ?? [];
    final modeStr = prefs.getString(hazukiCommentFilterModeKey);
    _mode = modeStr == 'hide'
        ? CommentFilterMode.hide
        : CommentFilterMode.collapse;
    if (notify) {
      notifyListeners();
    }
  }

  Future<void> save({
    required List<String> userKeywords,
    required CommentFilterMode mode,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final storedKeywords =
        prefs.getStringList(hazukiCommentFilterKeywordsKey) ?? const <String>[];
    final keywordsChanged = !listEquals(storedKeywords, userKeywords);
    _userKeywords = List.of(userKeywords);
    _mode = mode;
    await prefs.setStringList(hazukiCommentFilterKeywordsKey, _userKeywords);
    if (keywordsChanged) {
      final previousUpdatedAt =
          prefs.getInt(hazukiCommentFilterKeywordsUpdatedAtKey) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      await prefs.setInt(
        hazukiCommentFilterKeywordsUpdatedAtKey,
        now > previousUpdatedAt ? now : previousUpdatedAt + 1,
      );
    }
    await prefs.setString(hazukiCommentFilterModeKey, mode.name);
    notifyListeners();
  }

  @override
  Future<CommentFilterMergeSnapshot> captureMergeSnapshot() async {
    final prefs = await SharedPreferences.getInstance();
    return CommentFilterMergeSnapshot(
      keywords: prefs.getStringList(hazukiCommentFilterKeywordsKey) ?? const [],
      updatedAtMs: prefs.getInt(hazukiCommentFilterKeywordsUpdatedAtKey) ?? 0,
    );
  }

  @override
  Future<void> applyMergedKeywords(CommentFilterMergeSnapshot snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      hazukiCommentFilterKeywordsKey,
      snapshot.keywords,
    );
    if (snapshot.updatedAtMs > 0) {
      await prefs.setInt(
        hazukiCommentFilterKeywordsUpdatedAtKey,
        snapshot.updatedAtMs,
      );
    } else {
      await prefs.remove(hazukiCommentFilterKeywordsUpdatedAtKey);
    }
  }

  @override
  Future<void> applySyncedPreferences(
    Map<String, Object?> values, {
    bool stringifyUnknown = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    for (final entry in values.entries) {
      final key = entry.key;
      if (!commentFilterSyncPreferenceKeys.contains(key)) continue;
      final value = entry.value;
      if (value == null) {
        await prefs.remove(key);
      } else if (value is bool) {
        await prefs.setBool(key, value);
      } else if (value is int) {
        await prefs.setInt(key, value);
      } else if (value is double) {
        await prefs.setDouble(key, value);
      } else if (value is String) {
        await prefs.setString(key, value);
      } else if (value is List) {
        await prefs.setStringList(key, value.map((entry) => '$entry').toList());
      } else if (stringifyUnknown) {
        await prefs.setString(key, value.toString());
      }
    }
  }

  @override
  Future<void> reloadAfterExternalChange() => load(notify: true);

  // Spammers insert zero-width / invisible Unicode chars between characters
  // (e.g. 做[U+200B]爱) so that "做爱" keyword matching fails.
  static final _invisibleCharsPattern = RegExp(
    r'[\u{00AD}\u{200B}\u{200C}\u{200D}\u{200E}\u{200F}'
    r'\u{2060}\u{2061}\u{2062}\u{2063}\u{2064}'
    r'\u{FEFF}\u{180E}]',
    unicode: true,
  );
  static final _whitespacePattern = RegExp(r'\s+', unicode: true);

  static String _clean(String text) => text
      .replaceAll(_invisibleCharsPattern, '')
      // Normalize Windows-style line endings so \r\n == \n
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .toLowerCase();

  // For a multi-line keyword every non-empty line must appear in the content.
  // This prevents a single \r vs \n or minor encoding difference from breaking
  // a match when the user pastes an entire comment as the keyword.
  bool _matchesKeyword(String cleanedContent, String rawKeyword) {
    final cleanKeyword = _clean(rawKeyword);
    if (cleanKeyword.isEmpty) return false;
    if (cleanedContent.contains(cleanKeyword)) return true;
    final compactKeyword = cleanKeyword.replaceAll(_whitespacePattern, '');
    final compactContent = cleanedContent.replaceAll(_whitespacePattern, '');
    if (compactKeyword.isNotEmpty && compactContent.contains(compactKeyword)) {
      return true;
    }
    final lines = cleanKeyword
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.length > 1) {
      return lines.every((line) => cleanedContent.contains(line));
    }
    return false;
  }

  bool isFiltered(String content) {
    final cleaned = _clean(content);
    for (final keyword in _userKeywords) {
      if (_matchesKeyword(cleaned, keyword)) return true;
    }
    return false;
  }
}
