import 'dart:io';

import 'package:flutter/material.dart';

import '../../app/app.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/widgets.dart';
import '../about_page.dart';
import 'settings.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.appearanceSettings,
    required this.onAppearanceChanged,
    required this.locale,
    required this.onLocaleChanged,
    required this.cloudSyncPageBuilder,
    required this.labSettingsPageBuilder,
    required this.advancedSettingsPageBuilder,
  });

  final AppearanceSettingsData appearanceSettings;
  final AppearanceSettingsApplyCallback onAppearanceChanged;
  final Locale? locale;
  final Future<void> Function(Locale? locale) onLocaleChanged;
  final WidgetBuilder cloudSyncPageBuilder;
  final WidgetBuilder labSettingsPageBuilder;
  final WidgetBuilder advancedSettingsPageBuilder;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late AppearanceSettingsData _appearanceSettings;
  late Locale? _locale;

  @override
  void initState() {
    super.initState();
    _appearanceSettings = widget.appearanceSettings;
    _locale = widget.locale;
  }

  @override
  void didUpdateWidget(covariant SettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.appearanceSettings != widget.appearanceSettings) {
      _appearanceSettings = widget.appearanceSettings;
    }
    if (oldWidget.locale != widget.locale) {
      _locale = widget.locale;
    }
  }

  Future<void> _handleAppearanceChanged(
    AppearanceSettingsData next, {
    Offset? revealOrigin,
  }) async {
    setState(() {
      _appearanceSettings = next;
    });
    await widget.onAppearanceChanged(next, revealOrigin: revealOrigin);
  }

  Future<void> _handleLocaleChanged(Locale? locale) async {
    setState(() {
      _locale = locale;
    });
    await widget.onLocaleChanged(locale);
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: hazukiFrostedAppBar(
        context: context,
        title: Text(strings.settingsTitle),
      ),
      body: HazukiDesktopPageContainer(
        child: ListView(
          children: [
            ListTile(
              leading: const Icon(Icons.cached_outlined),
              title: Text(strings.settingsCacheTitle),
              subtitle: Text(strings.settingsCacheSubtitle),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const CacheSettingsPage(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: Text(strings.settingsDisplayTitle),
              subtitle: Text(strings.settingsDisplaySubtitle),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AppearanceSettingsPage(
                      appearanceSettings: _appearanceSettings,
                      onAppearanceChanged: _handleAppearanceChanged,
                      locale: _locale,
                      onLocaleChanged: _handleLocaleChanged,
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.auto_stories_outlined),
              title: Text(strings.settingsReadingTitle),
              subtitle: Text(strings.settingsReadingSubtitle),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ReadingSettingsPage(),
                  ),
                );
              },
            ),
            if (!Platform.isWindows)
              ListTile(
                leading: const Icon(Icons.security_outlined),
                title: Text(strings.settingsPrivacyTitle),
                subtitle: Text(strings.settingsPrivacySubtitle),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const PrivacySettingsPage(),
                    ),
                  );
                },
              ),
            ListTile(
              leading: const Icon(Icons.cloud_sync_outlined),
              title: Text(strings.settingsCloudSyncTitle),
              subtitle: Text(strings.settingsCloudSyncSubtitle),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: widget.cloudSyncPageBuilder),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.widgets_outlined),
              title: Text(strings.settingsOtherTitle),
              subtitle: Text(strings.settingsOtherSubtitle),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const OtherSettingsPage(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.science_outlined),
              title: Text(strings.settingsLabTitle),
              subtitle: Text(strings.settingsLabSubtitle),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: widget.labSettingsPageBuilder,
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings_applications_outlined),
              title: Text(strings.settingsAdvancedTitle),
              subtitle: Text(strings.settingsAdvancedSubtitle),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: widget.advancedSettingsPageBuilder,
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(strings.settingsAboutTitle),
              subtitle: const Text('Hazuki'),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const AboutPage()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
