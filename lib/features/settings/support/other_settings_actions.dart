import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hazuki/shared/preferences/hazuki_general_preferences_store.dart';
import 'package:hazuki/shared/windows/window_title_bar_control.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/services/discover_daily_recommendation_service.dart';
import 'package:hazuki/services/manga_download/manga_download_service.dart';
import 'package:hazuki/services/manga_download/manga_download_storage_support.dart';
import 'package:hazuki/widgets/widgets.dart';

class OtherSettingsSnapshot {
  const OtherSettingsSnapshot({
    required this.autoCheckInEnabled,
    required this.autoSourceUpdateCheckEnabled,
    required this.autoSoftwareUpdateCheckEnabled,
    required this.aggregateSearchEnabled,
    required this.comicIdSearchEnhanceEnabled,
    required this.discoverDailyRecommendationEnabled,
    required this.useSystemTitleBar,
    required this.mangaDownloadsRootPath,
    required this.loading,
  });

  final bool autoCheckInEnabled;
  final bool autoSourceUpdateCheckEnabled;
  final bool autoSoftwareUpdateCheckEnabled;
  final bool aggregateSearchEnabled;
  final bool comicIdSearchEnhanceEnabled;
  final bool discoverDailyRecommendationEnabled;
  final bool useSystemTitleBar;
  final String mangaDownloadsRootPath;
  final bool loading;

  OtherSettingsSnapshot copyWith({
    bool? autoCheckInEnabled,
    bool? autoSourceUpdateCheckEnabled,
    bool? autoSoftwareUpdateCheckEnabled,
    bool? aggregateSearchEnabled,
    bool? comicIdSearchEnhanceEnabled,
    bool? discoverDailyRecommendationEnabled,
    bool? useSystemTitleBar,
    String? mangaDownloadsRootPath,
    bool? loading,
  }) {
    return OtherSettingsSnapshot(
      autoCheckInEnabled: autoCheckInEnabled ?? this.autoCheckInEnabled,
      autoSourceUpdateCheckEnabled:
          autoSourceUpdateCheckEnabled ?? this.autoSourceUpdateCheckEnabled,
      autoSoftwareUpdateCheckEnabled:
          autoSoftwareUpdateCheckEnabled ?? this.autoSoftwareUpdateCheckEnabled,
      aggregateSearchEnabled:
          aggregateSearchEnabled ?? this.aggregateSearchEnabled,
      comicIdSearchEnhanceEnabled:
          comicIdSearchEnhanceEnabled ?? this.comicIdSearchEnhanceEnabled,
      discoverDailyRecommendationEnabled:
          discoverDailyRecommendationEnabled ??
          this.discoverDailyRecommendationEnabled,
      useSystemTitleBar: useSystemTitleBar ?? this.useSystemTitleBar,
      mangaDownloadsRootPath:
          mangaDownloadsRootPath ?? this.mangaDownloadsRootPath,
      loading: loading ?? this.loading,
    );
  }

  static OtherSettingsSnapshot initial({required bool useSystemTitleBar}) {
    return OtherSettingsSnapshot(
      autoCheckInEnabled: false,
      autoSourceUpdateCheckEnabled: true,
      autoSoftwareUpdateCheckEnabled: true,
      aggregateSearchEnabled: false,
      comicIdSearchEnhanceEnabled: false,
      discoverDailyRecommendationEnabled: false,
      useSystemTitleBar: useSystemTitleBar,
      mangaDownloadsRootPath: MangaDownloadAccess.defaultDownloadsRootPath,
      loading: true,
    );
  }
}

class OtherSettingsActions {
  const OtherSettingsActions._();

  static const _preferences = HazukiGeneralPreferencesStore();

  static Future<({bool source, bool software})>
  loadUpdateCheckSettings() async {
    return (
      source: await _preferences.loadAutoSourceUpdateCheckEnabled(),
      software: await _preferences.loadAutoSoftwareUpdateCheckEnabled(),
    );
  }

  static Future<OtherSettingsSnapshot> loadSettings({
    required bool initialUseSystemTitleBar,
  }) async {
    final updateChecks = await loadUpdateCheckSettings();
    final mangaDownloadsRootPath =
        await MangaDownloadAccess.loadDownloadsRootPath();
    return OtherSettingsSnapshot(
      autoCheckInEnabled: await _preferences.loadAutoCheckInEnabled(),
      autoSourceUpdateCheckEnabled: updateChecks.source,
      autoSoftwareUpdateCheckEnabled: updateChecks.software,
      aggregateSearchEnabled: await _preferences.loadAggregateSearchEnabled(),
      comicIdSearchEnhanceEnabled: await _preferences
          .loadComicIdSearchEnhanceEnabled(),
      discoverDailyRecommendationEnabled: await _preferences
          .loadDiscoverDailyRecommendationEnabled(),
      useSystemTitleBar: initialUseSystemTitleBar,
      mangaDownloadsRootPath: mangaDownloadsRootPath,
      loading: false,
    );
  }

  static bool resolveUseSystemTitleBarFromScope(
    BuildContext context, {
    required bool fallbackValue,
  }) {
    if (Theme.of(context).platform != TargetPlatform.windows) {
      return fallbackValue;
    }
    return HazukiWindowsTitleBarScope.of(context).useSystemTitleBar;
  }

  static Future<void> toggleAutoCheckIn(bool value) =>
      _preferences.saveAutoCheckInEnabled(value);

  static Future<void> toggleAggregateSearch(bool value) =>
      _preferences.saveAggregateSearchEnabled(value);

  static Future<void> toggleComicIdSearchEnhance(bool value) =>
      _preferences.saveComicIdSearchEnhanceEnabled(value);

  static Future<void> toggleAutoSourceUpdateCheck(
    BuildContext context,
    bool value,
  ) async {
    await _preferences.saveAutoSourceUpdateCheckEnabled(value);
    if (!context.mounted) {
      return;
    }
    await showHazukiPrompt(
      context,
      AppLocalizations.of(context)!.otherAutoUpdateUpdated,
    );
  }

  static Future<void> toggleAutoSoftwareUpdateCheck(
    BuildContext context,
    bool value,
  ) async {
    await _preferences.saveAutoSoftwareUpdateCheckEnabled(value);
    if (!context.mounted) {
      return;
    }
    await showHazukiPrompt(
      context,
      AppLocalizations.of(context)!.otherAutoSoftwareUpdateUpdated,
    );
  }

  static Future<void> toggleDiscoverDailyRecommendation(
    DiscoverDailyRecommendationService service,
    bool value,
  ) {
    return service.setEnabled(value);
  }

  static Future<String?> editMangaDownloadPath(
    BuildContext context, {
    required String currentPath,
    required MangaDownloadService downloadService,
  }) async {
    final strings = AppLocalizations.of(context)!;
    String? result;
    try {
      result = await MangaDownloadAccess.pickDownloadsRootPath(
        currentPath: currentPath,
      );
    } on PlatformException catch (error) {
      if (!context.mounted) {
        return null;
      }
      await showHazukiPrompt(
        context,
        strings.otherMangaDownloadPathPickFailed(error.message ?? error.code),
      );
      return null;
    } catch (error) {
      if (!context.mounted) {
        return null;
      }
      await showHazukiPrompt(
        context,
        strings.otherMangaDownloadPathPickFailed(error.toString()),
      );
      return null;
    }
    if (!context.mounted || result == null) {
      return null;
    }

    final normalized = MangaDownloadAccess.normalizeDownloadsRootPath(result);
    try {
      await downloadService.changeDownloadsRootPath(normalized);
    } catch (error) {
      if (!context.mounted) return null;
      await showHazukiPrompt(
        context,
        strings.otherMangaDownloadPathPickFailed(error.toString()),
      );
      return null;
    }
    if (!context.mounted) {
      return null;
    }
    await showHazukiPrompt(context, strings.otherMangaDownloadPathSaved);
    return normalized;
  }
}
