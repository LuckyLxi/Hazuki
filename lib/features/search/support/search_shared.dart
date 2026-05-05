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

Map<String, String> searchOrderLabels(BuildContext context) {
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

Future<String> normalizeSubmittedKeyword(
  String rawKeyword, {
  TextEditingController? controller,
}) async {
  var keyword = rawKeyword.trim();
  if (keyword.isEmpty) {
    return '';
  }

  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(hazukiComicIdSearchEnhancePreferenceKey) == true) {
    final extractedId = extractBestComicId(keyword);
    if (extractedId != null) {
      keyword = extractedId;
      controller?.value = TextEditingValue(
        text: keyword,
        selection: TextSelection.collapsed(offset: keyword.length),
      );
    }
  }
  return keyword;
}

Future<void> addSearchHistory(String keyword) async {
  await SearchHistoryService().add(keyword);
}
