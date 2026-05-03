import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hazuki/app/app.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/services/hazuki_source_service.dart';
import 'package:hazuki/widgets/sun_moon_icon.dart';
import '../display_mode_settings_page.dart';
import '../settings_group.dart';
import 'appearance_settings_locale_dialog.dart';

class AppearanceSettingsContent extends StatefulWidget {
  const AppearanceSettingsContent({
    super.key,
    required this.settings,
    required this.locale,
    required this.onApply,
    required this.onApplyLocale,
  });

  final AppearanceSettingsData settings;
  final Locale? locale;
  final AppearanceSettingsApplyCallback onApply;
  final Future<void> Function(Locale? locale) onApplyLocale;

  @override
  State<AppearanceSettingsContent> createState() =>
      _AppearanceSettingsContentState();
}

class _AppearanceSettingsContentState extends State<AppearanceSettingsContent> {
  final GlobalKey _themeIconKey = GlobalKey();

  void _logThemeUiEvent(
    String title, {
    String level = 'info',
    Map<String, Object?>? content,
  }) {
    HazukiSourceService.instance.addApplicationLog(
      level: level,
      title: title,
      source: 'appearance_theme_ui',
      content: {
        'route': 'appearance_settings',
        'themeModeSetting': widget.settings.themeMode.name,
        'effectiveBrightness': Theme.of(context).brightness.name,
        if (content != null) ...content,
      },
    );
  }

  String _localeLabel(AppLocalizations strings) {
    return switch (widget.locale?.languageCode) {
      'zh' => strings.displayLanguageZhHans,
      'en' => strings.displayLanguageEnglish,
      _ => strings.displayLanguageSystem,
    };
  }

  String _displayModeLabel(AppLocalizations strings) {
    final raw = widget.settings.displayModeRaw;
    if (raw == 'native:auto') {
      return strings.displayRefreshRateAuto;
    }
    if (raw.startsWith('native:')) {
      final id = raw.substring('native:'.length);
      return strings.displayRefreshRateSpecified(id);
    }
    return raw;
  }

  Future<void> _handleLocaleTap(BuildContext context) async {
    final next = await showAppearanceLocaleDialog(
      context,
      currentLocale: widget.locale,
    );
    if (next == null) {
      return;
    }
    final nextLocale = next.followSystem ? null : next.locale;
    if (widget.locale?.languageCode == nextLocale?.languageCode &&
        ((widget.locale != null) == (nextLocale != null))) {
      return;
    }
    await widget.onApplyLocale(nextLocale);
  }

  Offset? _themeToggleOrigin() {
    final iconContext = _themeIconKey.currentContext;
    final renderObject = iconContext?.findRenderObject();
    if (renderObject is! RenderBox) {
      _logThemeUiEvent(
        'Theme toggle origin unavailable',
        level: 'warning',
        content: {'reason': 'icon_render_box_not_found'},
      );
      return null;
    }
    final origin = renderObject.localToGlobal(
      renderObject.size.center(Offset.zero),
    );
    _logThemeUiEvent(
      'Theme toggle origin resolved',
      content: {'x': origin.dx.round(), 'y': origin.dy.round()},
    );
    return origin;
  }

  Future<void> _applyThemeMode(ThemeMode mode) async {
    if (widget.settings.themeMode == mode) {
      _logThemeUiEvent(
        'Theme mode apply skipped',
        content: {'requestedThemeMode': mode.name, 'reason': 'same_mode'},
      );
      return;
    }
    _logThemeUiEvent(
      'Theme mode apply requested',
      content: {'requestedThemeMode': mode.name},
    );
    await widget.onApply(
      widget.settings.copyWith(themeMode: mode),
      revealOrigin: _themeToggleOrigin(),
    );
  }

  Widget _buildThemeOption({
    required ThemeMode value,
    required IconData icon,
    required String label,
    required bool isSelected,
    required ColorScheme colorScheme,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: () => unawaited(_applyThemeMode(value)),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.primaryContainer
                : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.outlineVariant.withValues(alpha: 0.3),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
                size: 22,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final presetWidth = (MediaQuery.of(context).size.width - 96) / 3;

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SettingsGroup(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    strings.displayThemeTitle,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    key: _themeIconKey,
                    width: 20,
                    height: 20,
                    child: SunMoonIcon(
                      isDark: theme.brightness == Brightness.dark,
                      size: 20,
                      duration: const Duration(milliseconds: 600),
                      sunColor: colorScheme.primary,
                      moonColor: colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  _buildThemeOption(
                    value: ThemeMode.light,
                    icon: Icons.light_mode_rounded,
                    label: strings.displayThemeLight,
                    isSelected: widget.settings.themeMode == ThemeMode.light,
                    colorScheme: colorScheme,
                  ),
                  const SizedBox(width: 8),
                  _buildThemeOption(
                    value: ThemeMode.dark,
                    icon: Icons.dark_mode_rounded,
                    label: strings.displayThemeDark,
                    isSelected: widget.settings.themeMode == ThemeMode.dark,
                    colorScheme: colorScheme,
                  ),
                  const SizedBox(width: 8),
                  _buildThemeOption(
                    value: ThemeMode.system,
                    icon: Icons.settings_suggest_outlined,
                    label: strings.displayThemeSystem,
                    isSelected: widget.settings.themeMode == ThemeMode.system,
                    colorScheme: colorScheme,
                  ),
                ],
              ),
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            SwitchListTile(
              value: widget.settings.useSystemFont,
              title: Text(strings.displaySystemFontTitle),
              subtitle: Text(strings.displaySystemFontSubtitle),
              onChanged: (value) {
                unawaited(
                  widget.onApply(
                    widget.settings.copyWith(useSystemFont: value),
                  ),
                );
              },
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            SwitchListTile(
              value: widget.settings.oledPureBlack,
              title: Text(strings.displayPureBlackTitle),
              subtitle: Text(strings.displayPureBlackSubtitle),
              onChanged: (value) {
                unawaited(
                  widget.onApply(
                    widget.settings.copyWith(oledPureBlack: value),
                  ),
                );
              },
            ),
          ],
        ),
        SettingsGroup(
          children: [
            ListTile(
              leading: const Icon(Icons.language_rounded),
              title: Text(strings.displayLanguageTitle),
              subtitle: Text(_localeLabel(strings)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                unawaited(_handleLocaleTap(context));
              },
            ),
            const Divider(height: 1, indent: 56),
            ListTile(
              leading: const Icon(Icons.speed_rounded),
              title: Text(strings.displayRefreshRateTitle),
              subtitle: Text(_displayModeLabel(strings)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => DisplayModeSettingsPage(
                      currentDisplayModeRaw: widget.settings.displayModeRaw,
                      onDisplayModeChanged: (displayModeRaw) {
                        return widget.onApply(
                          widget.settings.copyWith(
                            displayModeRaw: displayModeRaw,
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        SettingsGroup(
          children: [
            SwitchListTile(
              secondary: const Icon(Icons.color_lens_outlined),
              value: widget.settings.dynamicColor,
              title: Text(strings.displayDynamicColorTitle),
              subtitle: Text(strings.displayDynamicColorSubtitle),
              onChanged: (value) {
                unawaited(
                  widget.onApply(widget.settings.copyWith(dynamicColor: value)),
                );
              },
            ),
            const Divider(height: 1, indent: 56),
            SwitchListTile(
              secondary: const Icon(Icons.format_paint_outlined),
              value: widget.settings.comicDetailDynamicColor,
              title: Text(strings.displayComicDynamicColorTitle),
              subtitle: Text(strings.displayComicDynamicColorSubtitle),
              onChanged: (value) {
                unawaited(
                  widget.onApply(
                    widget.settings.copyWith(comicDetailDynamicColor: value),
                  ),
                );
              },
            ),
            const Divider(height: 1, indent: 56),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                strings.displayColorSchemeTitle,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.primary,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: List<Widget>.generate(kHazukiColorPresets.length, (
                  index,
                ) {
                  final preset = kHazukiColorPresets[index];
                  final selected = widget.settings.presetIndex == index;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    width: presetWidth,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        unawaited(
                          widget.onApply(
                            widget.settings.copyWith(presetIndex: index),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? colorScheme.primaryContainer
                              : colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: selected
                                ? colorScheme.primary
                                : colorScheme.outlineVariant.withValues(
                                    alpha: 0.5,
                                  ),
                            width: selected ? 1.5 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: preset.seedColor,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  if (selected)
                                    BoxShadow(
                                      color: preset.seedColor.withValues(
                                        alpha: 0.4,
                                      ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              preset.labelBuilder(strings),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                color: selected
                                    ? colorScheme.onPrimaryContainer
                                    : colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
