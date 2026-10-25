import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/shared/source_presentation.dart';
import 'package:hazuki/services/source/plugins/source_sort_options.dart';
import 'search_contracts.dart';
import 'package:flutter/material.dart';
import 'package:hazuki/shared/preferences/hazuki_general_preferences_store.dart';
import 'package:hazuki/services/search_history_service.dart';

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
            sourceOrderLabel(value, language, key.toString()),
          ),
        )
      : const {};
}

Future<bool> isComicIdSearchEnhanceEnabled({
  HazukiGeneralPreferencesStore store = const HazukiGeneralPreferencesStore(),
}) => store.loadComicIdSearchEnhanceEnabled();

Future<bool> isAggregateSearchEnabled({
  HazukiGeneralPreferencesStore store = const HazukiGeneralPreferencesStore(),
}) => store.loadAggregateSearchEnabled();

Future<void> setAggregateSearchEnabled(
  bool enabled, {
  HazukiGeneralPreferencesStore store = const HazukiGeneralPreferencesStore(),
}) => store.saveAggregateSearchEnabled(enabled);

Future<SearchComicLayout> loadSearchComicLayout({
  HazukiGeneralPreferencesStore store = const HazukiGeneralPreferencesStore(),
}) async {
  final savedLayout = await store.loadSearchComicLayoutName();
  return SearchComicLayout.values.firstWhere(
    (layout) => layout.name == savedLayout,
    orElse: () => SearchComicLayout.list,
  );
}

Future<void> setSearchComicLayout(
  SearchComicLayout layout, {
  HazukiGeneralPreferencesStore store = const HazukiGeneralPreferencesStore(),
}) => store.saveSearchComicLayoutName(layout.name);

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
