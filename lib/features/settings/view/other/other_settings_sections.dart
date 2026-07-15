import 'package:flutter/material.dart';
import 'package:hazuki/l10n/app_localizations.dart';

import '../settings_group.dart';

class OtherSettingsGeneralSection extends StatelessWidget {
  const OtherSettingsGeneralSection({
    super.key,
    required this.autoCheckInEnabled,
    required this.discoverDailyRecommendationEnabled,
    required this.showAutoCheckInSetting,
    required this.showJmExclusiveSettings,
    required this.useSystemTitleBar,
    required this.mangaDownloadsRootPath,
    required this.showWindowsTitleBarToggle,
    required this.onAutoCheckInChanged,
    required this.onDiscoverDailyRecommendationChanged,
    required this.onUseSystemTitleBarChanged,
    required this.onEditMangaDownloadPath,
    required this.onCommentFilter,
  });

  final bool autoCheckInEnabled;
  final bool discoverDailyRecommendationEnabled;
  final bool showAutoCheckInSetting;
  final bool showJmExclusiveSettings;
  final bool useSystemTitleBar;
  final String mangaDownloadsRootPath;
  final bool showWindowsTitleBarToggle;
  final ValueChanged<bool> onAutoCheckInChanged;
  final ValueChanged<bool> onDiscoverDailyRecommendationChanged;
  final ValueChanged<bool> onUseSystemTitleBarChanged;
  final VoidCallback onEditMangaDownloadPath;
  final VoidCallback onCommentFilter;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return SettingsGroup(
      children: [
        if (showAutoCheckInSetting)
          SwitchListTile(
            secondary: const Icon(Icons.event_available_outlined),
            title: Text(strings.otherAutoCheckInTitle),
            subtitle: Text(strings.otherAutoCheckInSubtitle),
            value: autoCheckInEnabled,
            onChanged: onAutoCheckInChanged,
          ),
        if (showJmExclusiveSettings)
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
