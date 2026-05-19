import 'package:flutter/material.dart';
import 'package:hazuki/app/app.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'search_history_service.dart';

const searchLoadTimeout = Duration(seconds: 25);
const searchAppBarRevealOffset = 68.0;
const searchHistoryCollapsedMaxRows = 4;
const searchHistoryChipSpacing = 8.0;
const searchOrderKeys = <String>{
  'mr',
  'mv',
  'mv_m',
  'mv_w',
  'mv_t',
  'mp',
  'tf',
};
const copyMangaSourceKey = 'copy_manga';
const copyMangaSearchModeKeys = <String>{'-', 'name', 'author', 'local'};
const picacgSourceKey = 'picacg';
const picacgSearchOrderKeys = <String>{'dd', 'da', 'ld', 'vd'};

enum SearchEntryIntent {
  editFromEntry,
  submitFromEntry,
  historySelection,
  externalKeyword,
}

extension SearchEntryIntentExtension on SearchEntryIntent {
  bool get showKeyboardOnEnter => this == SearchEntryIntent.editFromEntry;
}

typedef SearchPageLoader =
    Future<SearchComicsResult> Function(
      BuildContext context, {
      required String keyword,
      required int page,
      required String order,
    });

Map<String, String> searchOrderLabels(
  BuildContext context, {
  String sourceKey = '',
}) {
  if (sourceKey.trim() == copyMangaSourceKey) {
    return const {'-': '全部', 'name': '名称', 'author': '作者', 'local': '汉化组'};
  }

  if (sourceKey.trim() == picacgSourceKey) {
    return const {
      'dd': 'New to old',
      'da': 'Old to new',
      'ld': 'Most likes',
      'vd': 'Most nominated',
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

String? normalizeDirectComicIdKeyword(String keyword) {
  final normalized = keyword.trim().toLowerCase();
  if (RegExp(r'^\d{2,}$').hasMatch(normalized)) {
    return normalized;
  }
  if (RegExp(r'^jm\d{2,}$').hasMatch(normalized)) {
    return normalized;
  }
  return null;
}

Future<bool> isComicIdSearchEnhanceEnabled() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(hazukiComicIdSearchEnhancePreferenceKey) == true;
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

Future<void> addSearchHistory(String keyword) async {
  await SearchHistoryService().add(keyword);
}
