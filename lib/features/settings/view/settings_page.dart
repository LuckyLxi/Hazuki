import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hazuki/shared/appearance/appearance_settings.dart';
import 'package:hazuki/shared/windows/window_title_bar_control.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/widgets/widgets.dart';
import 'package:hazuki/widgets/windows_comic_detail_host.dart';
import 'about_page.dart';
import 'appearance/appearance_settings_page.dart';
import 'cache_settings_page.dart';
import 'other/other_settings_page.dart';
import 'reading_settings_page.dart';
import 'plugins/source_plugins_page.dart';
import 'security/privacy_settings_page.dart';
import 'settings_group.dart';
import 'translation/manga_translation_settings_page.dart';
import '../support/settings_core_dependencies.dart';

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
    required this.coreDependencies,
  });

  final AppearanceSettingsData appearanceSettings;
  final AppearanceSettingsApplyCallback onAppearanceChanged;
  final Locale? locale;
  final Future<void> Function(Locale? locale) onLocaleChanged;
  final WidgetBuilder cloudSyncPageBuilder;
  final WidgetBuilder labSettingsPageBuilder;
  final WidgetBuilder advancedSettingsPageBuilder;
  final SettingsCoreDependencies coreDependencies;

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
    Rect? revealSyncRegion,
  }) async {
    setState(() {
      _appearanceSettings = next;
    });
    await widget.onAppearanceChanged(
      next,
      revealOrigin: revealOrigin,
      revealSyncRegion: revealSyncRegion,
    );
  }

  Future<void> _handleLocaleChanged(Locale? locale) async {
    setState(() {
      _locale = locale;
    });
    await widget.onLocaleChanged(locale);
  }

  void _open(WidgetBuilder builder) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: builder));
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final dependencies = widget.coreDependencies;
    return WindowsComicDetailHost(
      child: Scaffold(
        appBar: hazukiFrostedAppBar(
          context: context,
          title: Text(strings.settingsTitle),
        ),
        body: HazukiSettingsPageBody(
          maxWidth: 960,
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: ListView(
            padding: const EdgeInsets.only(top: 4, bottom: 24),
            children: [
              _SettingsSection(
                title: strings.settingsSectionAppearanceReading,
                entries: [
                  _SettingsEntryTile(
                    icon: Icons.palette_outlined,
                    title: strings.settingsDisplayTitle,
                    subtitle: strings.settingsDisplaySubtitle,
                    onTap: () => _open(
                      (_) => AppearanceSettingsPage(
                        appearanceSettings: _appearanceSettings,
                        onAppearanceChanged: _handleAppearanceChanged,
                        locale: _locale,
                        onLocaleChanged: _handleLocaleChanged,
                        debugGateway: dependencies.sourceDebug,
                      ),
                    ),
                  ),
                  _SettingsEntryTile(
                    icon: Icons.auto_stories_outlined,
                    title: strings.settingsReadingTitle,
                    subtitle: strings.settingsReadingSubtitle,
                    onTap: () => _open(
                      (_) => ReadingSettingsPage(
                        sourceService: dependencies.sourceSettings,
                        sourcePlugins: dependencies.sourcePlugins,
                      ),
                    ),
                  ),
                  if (dependencies.translation case final translation?)
                    _SettingsEntryTile(
                      icon: Icons.translate_rounded,
                      title: strings.translationTitle,
                      subtitle: strings.translationSettingsSubtitle,
                      onTap: () => _open(
                        (_) => MangaTranslationSettingsPage(
                          dependencies: translation,
                        ),
                      ),
                    ),
                ],
              ),
              _SettingsSection(
                title: strings.settingsSectionContentData,
                entries: [
                  if (dependencies.sourcePlugins case final plugins?)
                    _SettingsEntryTile(
                      icon: Icons.extension_outlined,
                      title: strings.settingsPluginsTitle,
                      subtitle: strings.settingsPluginsSubtitle,
                      onTap: () =>
                          _open((_) => SourcePluginsPage(manager: plugins)),
                    ),
                  _SettingsEntryTile(
                    icon: Icons.cloud_sync_outlined,
                    title: strings.settingsCloudSyncTitle,
                    subtitle: strings.settingsCloudSyncSubtitle,
                    onTap: () => _open(widget.cloudSyncPageBuilder),
                  ),
                  _SettingsEntryTile(
                    icon: Icons.cached_outlined,
                    title: strings.settingsCacheTitle,
                    subtitle: strings.settingsCacheSubtitle,
                    onTap: () => _open(
                      (_) => CacheSettingsPage(
                        sourceService: dependencies.sourceSettings,
                      ),
                    ),
                  ),
                ],
              ),
              _SettingsSection(
                title: strings.settingsSectionSystem,
                entries: [
                  if (!Platform.isWindows)
                    _SettingsEntryTile(
                      icon: Icons.security_outlined,
                      title: strings.settingsPrivacyTitle,
                      subtitle: strings.settingsPrivacySubtitle,
                      onTap: () => _open(
                        (_) => PrivacySettingsPage(
                          passwordLockService: dependencies.passwordLock,
                        ),
                      ),
                    ),
                  _SettingsEntryTile(
                    icon: Icons.widgets_outlined,
                    title: strings.settingsOtherTitle,
                    subtitle: strings.settingsOtherSubtitle,
                    onTap: () {
                      final titleBarController = HazukiWindowsTitleBarScope.of(
                        context,
                      );
                      _open(
                        (_) => OtherSettingsPage(
                          dependencies: dependencies,
                          initialUseSystemTitleBar:
                              titleBarController.useSystemTitleBar,
                          onUseSystemTitleBarChanged:
                              titleBarController.updateUseSystemTitleBar,
                        ),
                      );
                    },
                  ),
                  _SettingsEntryTile(
                    icon: Icons.science_outlined,
                    title: strings.settingsLabTitle,
                    subtitle: strings.settingsLabSubtitle,
                    onTap: () => _open(widget.labSettingsPageBuilder),
                  ),
                  _SettingsEntryTile(
                    icon: Icons.settings_applications_outlined,
                    title: strings.settingsAdvancedTitle,
                    subtitle: strings.settingsAdvancedSubtitle,
                    onTap: () => _open(widget.advancedSettingsPageBuilder),
                  ),
                ],
              ),
              _SettingsSection(
                title: strings.settingsAboutTitle,
                entries: [
                  _SettingsEntryTile(
                    icon: Icons.info_outline,
                    title: strings.settingsAboutTitle,
                    subtitle: 'Hazuki',
                    onTap: () => _open(
                      (_) => AboutPage(
                        softwareUpdateDialog: dependencies.softwareUpdateDialog,
                        softwareUpdateService: dependencies.softwareUpdate,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 设置主页的一个分区：主题色标题 + 圆角卡片，条目之间插入缩进分隔线。
class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.entries});

  final String title;
  final List<Widget> entries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final divider = Divider(
      height: 1,
      indent: 72,
      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 16, 28, 0),
          child: Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        SettingsGroup(
          children: [
            for (var i = 0; i < entries.length; i++) ...[
              if (i > 0) divider,
              entries[i],
            ],
          ],
        ),
      ],
    );
  }
}

/// 设置主页入口条目：圆形色块图标 + 标题副标题 + 右侧箭头。
class _SettingsEntryTile extends StatelessWidget {
  const _SettingsEntryTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      minTileHeight: 72,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: colorScheme.secondaryContainer,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 22, color: colorScheme.onSecondaryContainer),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}
