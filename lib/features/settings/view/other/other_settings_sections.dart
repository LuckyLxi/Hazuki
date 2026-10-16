import 'package:flutter/material.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/services/chinese_conversion_service.dart';

import '../settings_group.dart';
import 'chinese_conversion_setting.dart';

class OtherSettingsGeneralSection extends StatelessWidget {
  const OtherSettingsGeneralSection({
    super.key,
    required this.autoCheckInEnabled,
    required this.aggregateSearchEnabled,
    required this.comicIdSearchEnhanceEnabled,
    required this.discoverDailyRecommendationEnabled,
    required this.showAutoCheckInSetting,
    required this.showDailyRecommendationSetting,
    required this.showComicIdSearchSetting,
    required this.useSystemTitleBar,
    required this.mangaDownloadsRootPath,
    required this.showWindowsTitleBarToggle,
    required this.onAutoCheckInChanged,
    required this.onAggregateSearchChanged,
    required this.onComicIdSearchEnhanceChanged,
    required this.onDiscoverDailyRecommendationChanged,
    required this.onUseSystemTitleBarChanged,
    required this.onEditMangaDownloadPath,
    required this.onCommentFilter,
    required this.onChineseConversionChanged,
    this.chineseConversionEnabled = true,
  });

  final bool autoCheckInEnabled;
  final bool aggregateSearchEnabled;
  final bool comicIdSearchEnhanceEnabled;
  final bool discoverDailyRecommendationEnabled;
  final bool showAutoCheckInSetting;
  final bool showDailyRecommendationSetting;
  final bool showComicIdSearchSetting;
  final bool useSystemTitleBar;
  final String mangaDownloadsRootPath;
  final bool showWindowsTitleBarToggle;
  final ValueChanged<bool> onAutoCheckInChanged;
  final ValueChanged<bool> onAggregateSearchChanged;
  final ValueChanged<bool> onComicIdSearchEnhanceChanged;
  final ValueChanged<bool> onDiscoverDailyRecommendationChanged;
  final ValueChanged<bool> onUseSystemTitleBarChanged;
  final VoidCallback onEditMangaDownloadPath;
  final VoidCallback onCommentFilter;
  final ValueChanged<ChineseConversionMode> onChineseConversionChanged;
  final bool chineseConversionEnabled;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return SettingsGroup(
      children: [
        ChineseConversionSetting(
          onChanged: onChineseConversionChanged,
          enabled: chineseConversionEnabled,
        ),
        if (showAutoCheckInSetting)
          SwitchListTile(
            secondary: const Icon(Icons.event_available_outlined),
            title: Text(strings.otherAutoCheckInTitle),
            subtitle: Text(strings.otherAutoCheckInSubtitle),
            value: autoCheckInEnabled,
            onChanged: onAutoCheckInChanged,
          ),
        SwitchListTile(
          key: const ValueKey('other-aggregate-search-switch'),
          secondary: const Icon(Icons.travel_explore_outlined),
          title: Text(strings.searchAggregateSearch),
          subtitle: Text(strings.searchAggregateSearchDescription),
          value: aggregateSearchEnabled,
          onChanged: onAggregateSearchChanged,
        ),
        if (showComicIdSearchSetting)
          SwitchListTile(
            secondary: const Icon(Icons.tag_outlined),
            title: Text(strings.advancedComicIdSearchTitle),
            subtitle: Text(strings.advancedComicIdSearchSubtitle),
            value: comicIdSearchEnhanceEnabled,
            onChanged: onComicIdSearchEnhanceChanged,
          ),
        if (showDailyRecommendationSetting)
          SwitchListTile(
            secondary: const Icon(Icons.auto_awesome_outlined),
            title: Text(strings.otherDiscoverDailyRecommendationTitle),
            subtitle: Text(strings.otherDiscoverDailyRecommendationSubtitle),
            value: discoverDailyRecommendationEnabled,
            onChanged: onDiscoverDailyRecommendationChanged,
          ),
        if (showWindowsTitleBarToggle)
          SwitchListTile(
            secondary: const Icon(Icons.web_asset_outlined),
            title: Text(strings.otherUseSystemTitleBarTitle),
            subtitle: Text(strings.otherUseSystemTitleBarSubtitle),
            value: useSystemTitleBar,
            onChanged: onUseSystemTitleBarChanged,
          ),
        ListTile(
          leading: const Icon(Icons.folder_outlined),
          title: Text(strings.otherMangaDownloadPathTitle),
          subtitle: Text(mangaDownloadsRootPath),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: onEditMangaDownloadPath,
        ),
        ListTile(
          leading: const Icon(Icons.filter_alt_outlined),
          title: Text(strings.otherCommentFilterTitle),
          subtitle: Text(strings.otherCommentFilterSubtitle),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: onCommentFilter,
        ),
      ],
    );
  }
}
