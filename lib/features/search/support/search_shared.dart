import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/shared/source_presentation.dart';
import 'search_contracts.dart';
import 'package:flutter/material.dart';
import 'package:hazuki/shared/preferences/hazuki_preference_keys.dart';
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
  final options = sourcePresentation(
    sourceKey,
    context: context,
  )['searchOrders'];
  final language = Localizations.localeOf(context).languageCode;
  return options is Map
      ? options.map(
          (key, value) => MapEntry(
            key.toString(),
            value is Map
                ? (value[language] ??
                          value['en'] ??
                          value.values.firstOrNull ??
                          key)
                      .toString()
                : value.toString(),
          ),
        )
      : const {};
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
