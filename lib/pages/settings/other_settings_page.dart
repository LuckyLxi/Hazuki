import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/app.dart';
import '../../app/windows_title_bar_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../services/discover_daily_recommendation_service.dart';
import '../../services/manga_download_service.dart';
import '../../services/manga_download_storage_support.dart';
import '../../widgets/widgets.dart';
import 'settings_group.dart';

class OtherSettingsPage extends StatefulWidget {
  const OtherSettingsPage({
    super.key,
    this.initialUseSystemTitleBar = false,
    this.onUseSystemTitleBarChanged,
  });

  final bool initialUseSystemTitleBar;
  final Future<void> Function(bool value)? onUseSystemTitleBarChanged;

  @override
  State<OtherSettingsPage> createState() => _OtherSettingsPageState();
}

class _OtherSettingsPageState extends State<OtherSettingsPage> {
  bool _autoCheckInEnabled = false;
  bool _autoSourceUpdateCheckEnabled = true;
  bool _autoSoftwareUpdateCheckEnabled = true;
  bool _discoverDailyRecommendationEnabled = false;
  late bool _useSystemTitleBar = widget.initialUseSystemTitleBar;
  String _mangaDownloadsRootPath = MangaDownloadAccess.defaultDownloadsRootPath;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_loadSettings());
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final mangaDownloadsRootPath =
        await MangaDownloadAccess.loadDownloadsRootPath(prefs: prefs);
    if (!mounted) {
      return;
    }
    setState(() {
      _autoCheckInEnabled =
          prefs.getBool(hazukiAutoCheckInEnabledPreferenceKey) ?? false;
      _autoSourceUpdateCheckEnabled =
          prefs.getBool(hazukiAutoSourceUpdateCheckEnabledPreferenceKey) ??
          true;
      _autoSoftwareUpdateCheckEnabled =
          prefs.getBool(hazukiAutoSoftwareUpdateCheckEnabledPreferenceKey) ??
          true;
      _discoverDailyRecommendationEnabled =
          prefs.getBool(
            hazukiDiscoverDailyRecommendationEnabledPreferenceKey,
          ) ??
          false;
      _mangaDownloadsRootPath = mangaDownloadsRootPath;
      _loading = false;
    });
  }

  Future<void> _toggleAutoCheckIn(bool value) async {
    setState(() => _autoCheckInEnabled = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(hazukiAutoCheckInEnabledPreferenceKey, value);
  }

  Future<void> _toggleAutoSourceUpdateCheck(bool value) async {
    setState(() => _autoSourceUpdateCheckEnabled = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(hazukiAutoSourceUpdateCheckEnabledPreferenceKey, value);
    if (!mounted) {
      return;
    }
    await showHazukiPrompt(
      context,
      AppLocalizations.of(context)!.otherAutoUpdateUpdated,
    );
  }

  Future<void> _toggleAutoSoftwareUpdateCheck(bool value) async {
    setState(() => _autoSoftwareUpdateCheckEnabled = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(
      hazukiAutoSoftwareUpdateCheckEnabledPreferenceKey,
      value,
    );
    if (!mounted) {
      return;
    }
    await showHazukiPrompt(
      context,
      AppLocalizations.of(context)!.otherAutoSoftwareUpdateUpdated,
    );
  }

  Future<void> _toggleDiscoverDailyRecommendation(bool value) async {
    setState(() => _discoverDailyRecommendationEnabled = value);
    await DiscoverDailyRecommendationService.instance.setEnabled(value);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Theme.of(context).platform == TargetPlatform.windows) {
      _useSystemTitleBar = HazukiWindowsTitleBarScope.of(
        context,
      ).useSystemTitleBar;
    }
  }

  Future<void> _toggleUseSystemTitleBar(bool value) async {
    setState(() => _useSystemTitleBar = value);
    await widget.onUseSystemTitleBarChanged?.call(value);
  }

  Future<void> _editMangaDownloadPath() async {
    final strings = AppLocalizations.of(context)!;
    String? result;
    try {
      result = await MangaDownloadAccess.pickDownloadsRootPath(
        currentPath: _mangaDownloadsRootPath,
      );
    } on PlatformException catch (error) {
      if (!mounted) {
        return;
      }
      await showHazukiPrompt(
        context,
        strings.otherMangaDownloadPathPickFailed(error.message ?? error.code),
      );
      return;
    } catch (error) {
      if (!mounted) {
        return;
      }
      await showHazukiPrompt(
        context,
        strings.otherMangaDownloadPathPickFailed(error.toString()),
      );
      return;
    }
    if (!mounted || result == null) {
      return;
    }

    final normalized = MangaDownloadAccess.normalizeDownloadsRootPath(result);
    await MangaDownloadAccess.saveDownloadsRootPath(normalized);
    await MangaDownloadAccess.ensureNoMediaMarkerForPath(normalized);
    await MangaDownloadService.instance.handleRootPathChanged();
    if (!mounted) {
      return;
    }
    setState(() {
      _mangaDownloadsRootPath = normalized;
    });
    await showHazukiPrompt(context, strings.otherMangaDownloadPathSaved);
  }

  Widget _buildGroup(BuildContext context, {required List<Widget> children}) {
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

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: hazukiFrostedAppBar(
        context: context,
        title: Text(strings.otherTitle),
      ),
      body: HazukiSettingsPageBody(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _buildGroup(
                    context,
                    children: [
                      SwitchListTile(
                        secondary: const Icon(Icons.event_available_outlined),
                        title: Text(strings.otherAutoCheckInTitle),
                        subtitle: Text(strings.otherAutoCheckInSubtitle),
                        value: _autoCheckInEnabled,
                        onChanged: _toggleAutoCheckIn,
                      ),
                      SwitchListTile(
                        secondary: const Icon(Icons.system_update_alt_rounded),
                        title: Text(strings.otherAutoSourceUpdateTitle),
                        subtitle: Text(strings.otherAutoSourceUpdateSubtitle),
                        value: _autoSourceUpdateCheckEnabled,
                        onChanged: _toggleAutoSourceUpdateCheck,
                      ),
                      SwitchListTile(
                        secondary: const Icon(Icons.mobile_friendly_rounded),
                        title: Text(strings.otherAutoSoftwareUpdateTitle),
                        subtitle: Text(strings.otherAutoSoftwareUpdateSubtitle),
                        value: _autoSoftwareUpdateCheckEnabled,
                        onChanged: _toggleAutoSoftwareUpdateCheck,
                      ),
                      SwitchListTile(
                        secondary: const Icon(Icons.auto_awesome_outlined),
                        title: Text(
                          strings.otherDiscoverDailyRecommendationTitle,
                        ),
                        subtitle: Text(
                          strings.otherDiscoverDailyRecommendationSubtitle,
                        ),
                        value: _discoverDailyRecommendationEnabled,
                        onChanged: _toggleDiscoverDailyRecommendation,
                      ),
                      if (Theme.of(context).platform == TargetPlatform.windows)
                        SwitchListTile(
                          secondary: const Icon(Icons.web_asset_outlined),
                          title: Text(strings.otherUseSystemTitleBarTitle),
                          subtitle: Text(
                            strings.otherUseSystemTitleBarSubtitle,
                          ),
                          value: _useSystemTitleBar,
                          onChanged: _toggleUseSystemTitleBar,
                        ),
                      ListTile(
                        leading: const Icon(Icons.folder_outlined),
                        title: Text(strings.otherMangaDownloadPathTitle),
                        subtitle: Text(_mangaDownloadsRootPath),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: _editMangaDownloadPath,
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}
