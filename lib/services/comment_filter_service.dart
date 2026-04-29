import 'package:shared_preferences/shared_preferences.dart';

import 'package:hazuki/app/app_preferences.dart';

enum CommentFilterMode { collapse, hide }

class CommentFilterService {
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

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _userKeywords = prefs.getStringList(hazukiCommentFilterKeywordsKey) ?? [];
    final modeStr = prefs.getString(hazukiCommentFilterModeKey);
    _mode = modeStr == 'hide'
        ? CommentFilterMode.hide
        : CommentFilterMode.collapse;
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
  }

  bool isFiltered(String content) {
    final lower = content.toLowerCase();
    for (final phrase in builtinPhrases) {
      if (lower.contains(phrase)) return true;
    }
    for (final keyword in _userKeywords) {
      if (keyword.isNotEmpty && lower.contains(keyword.toLowerCase())) {
        return true;
      }
    }
    return false;
  }
}
