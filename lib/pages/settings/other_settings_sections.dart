import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

class OtherSettingsGeneralSection extends StatelessWidget {
  const OtherSettingsGeneralSection({
    super.key,
    required this.autoCheckInEnabled,
    required this.autoSourceUpdateCheckEnabled,
    required this.autoSoftwareUpdateCheckEnabled,
    required this.discoverDailyRecommendationEnabled,
    required this.useSystemTitleBar,
    required this.mangaDownloadsRootPath,
    required this.showWindowsTitleBarToggle,
    required this.onAutoCheckInChanged,
    required this.onAutoSourceUpdateChanged,
    required this.onAutoSoftwareUpdateChanged,
    required this.onDiscoverDailyRecommendationChanged,
    required this.onUseSystemTitleBarChanged,
    required this.onEditMangaDownloadPath,
  });

  final bool autoCheckInEnabled;
  final bool autoSourceUpdateCheckEnabled;
  final bool autoSoftwareUpdateCheckEnabled;
  final bool discoverDailyRecommendationEnabled;
  final bool useSystemTitleBar;
  final String mangaDownloadsRootPath;
  final bool showWindowsTitleBarToggle;
  final ValueChanged<bool> onAutoCheckInChanged;
  final ValueChanged<bool> onAutoSourceUpdateChanged;
  final ValueChanged<bool> onAutoSoftwareUpdateChanged;
  final ValueChanged<bool> onDiscoverDailyRecommendationChanged;
  final ValueChanged<bool> onUseSystemTitleBarChanged;
  final VoidCallback onEditMangaDownloadPath;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return _OtherSettingsGroup(
      children: [
        SwitchListTile(
          secondary: const Icon(Icons.event_available_outlined),
          title: Text(strings.otherAutoCheckInTitle),
          subtitle: Text(strings.otherAutoCheckInSubtitle),
          value: autoCheckInEnabled,
          onChanged: onAutoCheckInChanged,
        ),
        SwitchListTile(
          secondary: const Icon(Icons.system_update_alt_rounded),
          title: Text(strings.otherAutoSourceUpdateTitle),
          subtitle: Text(strings.otherAutoSourceUpdateSubtitle),
          value: autoSourceUpdateCheckEnabled,
          onChanged: onAutoSourceUpdateChanged,
        ),
        SwitchListTile(
          secondary: const Icon(Icons.mobile_friendly_rounded),
          title: Text(strings.otherAutoSoftwareUpdateTitle),
          subtitle: Text(strings.otherAutoSoftwareUpdateSubtitle),
          value: autoSoftwareUpdateCheckEnabled,
          onChanged: onAutoSoftwareUpdateChanged,
        ),
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
      ],
    );
  }
}

class _OtherSettingsGroup extends StatelessWidget {
  const _OtherSettingsGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}
