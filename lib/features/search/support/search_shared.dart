import 'search_contracts.dart';
import 'package:flutter/material.dart';
import 'package:hazuki/shared/preferences/hazuki_preference_keys.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/services/search_history_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

export 'search_contracts.dart';

enum SearchEntryIntent {
  editFromEntry,
  submitFromEntry,
  historySelection,
  externalKeyword,
}

enum SearchComicLayout { list, grid3 }

extension SearchEntryIntentExtension on SearchEntryIntent {
  bool get showKeyboardOnEnter => this == SearchEntryIntent.editFromEntry;
}

Map<String, String> searchOrderLabels(
  BuildContext context, {
  String sourceKey = '',
}) {
  if (sourceKey.trim() == copyMangaSourceKey) {
    return const {'-': '全部', 'name': '名称', 'author': '作者', 'local': '汉化组'};
  }

  if (sourceKey.trim() == picacgSourceKey) {
    final locale = Localizations.localeOf(context);
    final useChinese = locale.languageCode == 'zh';
    return {
      'dd': useChinese ? '新到旧' : 'New to old',
      'da': useChinese ? '旧到新' : 'Old to new',
      'ld': useChinese ? '最多喜欢' : 'Most likes',
      'vd': useChinese ? '最多指名' : 'Most nominated',
    };
  }

  final strings = AppLocalizations.of(context)!;
  return {
    'mr': strings.searchOrderLatest,
    'mv': strings.searchOrderTotalRanking,
    'mv_m': strings.searchOrderMonthlyRanking,
    'mv_w': strings.searchOrderWeeklyRanking,
    'mv_t': strings.searchOrderDailyRanking,
    'mp': strings.searchOrderMostImages,
    'tf': strings.searchOrderMostLikes,
  };
}

String? extractBestComicId(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null;
  final digitsOnly = trimmed.replaceAll(RegExp(r'[^\d]'), '');
  if (digitsOnly.length > 2 && digitsOnly != trimmed) return digitsOnly;
  return null;
}

Future<bool> isComicIdSearchEnhanceEnabled() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(hazukiComicIdSearchEnhancePreferenceKey) == true;
}

Future<bool> isAggregateSearchEnabled() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(hazukiAggregateSearchEnabledPreferenceKey) == true;
}

Future<void> setAggregateSearchEnabled(bool enabled) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(hazukiAggregateSearchEnabledPreferenceKey, enabled);
}

Future<SearchComicLayout> loadSearchComicLayout() async {
  final prefs = await SharedPreferences.getInstance();
  final savedLayout = prefs.getString(hazukiSearchComicLayoutPreferenceKey);
  return SearchComicLayout.values.firstWhere(
    (layout) => layout.name == savedLayout,
    orElse: () => SearchComicLayout.list,
  );
}

Future<void> setSearchComicLayout(SearchComicLayout layout) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(hazukiSearchComicLayoutPreferenceKey, layout.name);
}

Future<String> normalizeSubmittedKeyword(
  String rawKeyword, {
  TextEditingController? controller,
}) async {
  final keyword = rawKeyword.trim();
  controller?.value = TextEditingValue(
    text: keyword,
    selection: TextSelection.collapsed(offset: keyword.length),
  );
  return keyword;
}

Future<void> addSearchHistory(
  SearchHistoryService historyService,
  String keyword,
) async {
  await historyService.add(keyword);
}

SearchMessages searchMessages(BuildContext context) {
  final strings = AppLocalizations.of(context)!;
  return SearchMessages(
    timeout: strings.searchTimeout,
    failed: strings.searchFailed,
  );
}
