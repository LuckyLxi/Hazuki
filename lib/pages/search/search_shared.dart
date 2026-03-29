import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/app_localizations.dart';

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

Future<String> normalizeSubmittedKeyword(
  String rawKeyword, {
  TextEditingController? controller,
}) async {
  var keyword = rawKeyword.trim();
  if (keyword.isEmpty) {
    return '';
  }

  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool('advanced_comic_id_search_enhance') == true) {
    final digitsOnly = keyword.replaceAll(RegExp(r'[^\d]'), '');
    if (digitsOnly.length > 2 && digitsOnly != keyword) {
      keyword = digitsOnly;
      controller?.value = TextEditingValue(
        text: keyword,
        selection: TextSelection.collapsed(offset: keyword.length),
      );
    }
  }
  return keyword;
}

Future<void> addSearchHistory(String keyword) async {
  if (keyword.isEmpty) {
    return;
  }
  final prefs = await SharedPreferences.getInstance();
  final history = prefs.getStringList('search_history') ?? const <String>[];
  final newHistory = [keyword, ...history.where((e) => e != keyword)];
  if (newHistory.length > 50) {
    newHistory.removeRange(50, newHistory.length);
  }
  await prefs.setStringList('search_history', newHistory);
}
