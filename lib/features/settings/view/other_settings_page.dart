import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/widgets/widgets.dart';
import 'comment_filter_dialog.dart';
import 'other_settings_sections.dart';
import 'settings_group.dart';
import '../support/other_settings_actions.dart';

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
  late OtherSettingsSnapshot _snapshot = OtherSettingsSnapshot.initial(
    useSystemTitleBar: widget.initialUseSystemTitleBar,
  );

  @override
  void initState() {
    super.initState();
    unawaited(_loadSettings());
  }

  Future<void> _loadSettings() async {
    final snapshot = await OtherSettingsActions.loadSettings(
      initialUseSystemTitleBar: widget.initialUseSystemTitleBar,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _snapshot = snapshot;
    });
  }

  Future<void> _toggleAutoCheckIn(bool value) async {
    setState(() {
      _snapshot = _snapshot.copyWith(autoCheckInEnabled: value);
    });
    await OtherSettingsActions.toggleAutoCheckIn(value);
  }

  Future<void> _toggleAutoSourceUpdateCheck(bool value) async {
    setState(() {
      _snapshot = _snapshot.copyWith(autoSourceUpdateCheckEnabled: value);
    });
    await OtherSettingsActions.toggleAutoSourceUpdateCheck(context, value);
  }

  Future<void> _toggleAutoSoftwareUpdateCheck(bool value) async {
    setState(() {
      _snapshot = _snapshot.copyWith(autoSoftwareUpdateCheckEnabled: value);
    });
    await OtherSettingsActions.toggleAutoSoftwareUpdateCheck(context, value);
  }

  Future<void> _toggleDiscoverDailyRecommendation(bool value) async {
    setState(() {
      _snapshot = _snapshot.copyWith(discoverDailyRecommendationEnabled: value);
    });
    await OtherSettingsActions.toggleDiscoverDailyRecommendation(value);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _snapshot = _snapshot.copyWith(
      useSystemTitleBar: OtherSettingsActions.resolveUseSystemTitleBarFromScope(
        context,
        fallbackValue: _snapshot.useSystemTitleBar,
      ),
    );
  }

  Future<void> _toggleUseSystemTitleBar(bool value) async {
    setState(() {
      _snapshot = _snapshot.copyWith(useSystemTitleBar: value);
    });
    await widget.onUseSystemTitleBarChanged?.call(value);
  }

  Future<void> _openCommentFilter() {
    return showCommentFilterDialog(context);
  }

  Future<void> _editMangaDownloadPath() async {
    final nextPath = await OtherSettingsActions.editMangaDownloadPath(
      context,
      currentPath: _snapshot.mangaDownloadsRootPath,
    );
    if (!mounted || nextPath == null) {
      return;
    }
    setState(() {
      _snapshot = _snapshot.copyWith(mangaDownloadsRootPath: nextPath);
    });
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
        child: _snapshot.loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  OtherSettingsGeneralSection(
                    autoCheckInEnabled: _snapshot.autoCheckInEnabled,
                    autoSourceUpdateCheckEnabled:
                        _snapshot.autoSourceUpdateCheckEnabled,
                    autoSoftwareUpdateCheckEnabled:
                        _snapshot.autoSoftwareUpdateCheckEnabled,
                    discoverDailyRecommendationEnabled:
                        _snapshot.discoverDailyRecommendationEnabled,
                    useSystemTitleBar: _snapshot.useSystemTitleBar,
                    mangaDownloadsRootPath: _snapshot.mangaDownloadsRootPath,
                    showWindowsTitleBarToggle:
                        Theme.of(context).platform == TargetPlatform.windows,
                    onAutoCheckInChanged: _toggleAutoCheckIn,
                    onAutoSourceUpdateChanged: _toggleAutoSourceUpdateCheck,
                    onAutoSoftwareUpdateChanged: _toggleAutoSoftwareUpdateCheck,
                    onDiscoverDailyRecommendationChanged:
                        _toggleDiscoverDailyRecommendation,
                    onUseSystemTitleBarChanged: _toggleUseSystemTitleBar,
                    onEditMangaDownloadPath: () =>
                        unawaited(_editMangaDownloadPath()),
                    onCommentFilter: () => unawaited(_openCommentFilter()),
                  ),
                ],
              ),
      ),
    );
  }
}
