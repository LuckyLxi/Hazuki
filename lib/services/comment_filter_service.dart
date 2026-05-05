import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hazuki/app/app_preferences.dart';

enum CommentFilterMode { collapse, hide }

class CommentFilterService with ChangeNotifier {
  static final instance = CommentFilterService._();
  CommentFilterService._();

  static const builtinPhrases = [
    '萝莉视频',
    '幼和禁区',
    '禁区视频',
    '把我头像的链接',
    '输入浏览器',
    '已去广告',
    '免费发个',
    '拿走不用谢',
  ];

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
    _userKeywords = List.of(userKeywords);
    _mode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(hazukiCommentFilterKeywordsKey, _userKeywords);
    await prefs.setString(hazukiCommentFilterModeKey, mode.name);
    notifyListeners();
  }

  // Spammers insert zero-width / invisible Unicode chars between characters
  // (e.g. 做[U+200B]爱) so that "做爱" keyword matching fails.
  static final _invisibleCharsPattern = RegExp(
    r'[\u{00AD}\u{200B}\u{200C}\u{200D}\u{200E}\u{200F}'
    r'\u{2060}\u{2061}\u{2062}\u{2063}\u{2064}'
    r'\u{FEFF}\u{180E}]',
    unicode: true,
  );

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
    for (final phrase in builtinPhrases) {
      if (cleaned.contains(phrase)) return true;
    }
    for (final keyword in _userKeywords) {
      if (_matchesKeyword(cleaned, keyword)) return true;
    }
    return false;
  }
}
