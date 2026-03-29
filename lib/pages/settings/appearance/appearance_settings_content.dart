import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/app.dart';
import '../../../l10n/app_localizations.dart';
import '../display_mode_settings_page.dart';
import '../settings_group.dart';
import 'appearance_settings_locale_dialog.dart';

class AppearanceSettingsContent extends StatelessWidget {
  const AppearanceSettingsContent({
    super.key,
    required this.settings,
    required this.locale,
    required this.onApply,
    required this.onApplyLocale,
  });

  final AppearanceSettingsData settings;
  final Locale? locale;
  final Future<void> Function(AppearanceSettingsData next) onApply;
  final Future<void> Function(Locale? locale) onApplyLocale;

  String _localeLabel(AppLocalizations strings) {
    return switch (locale?.languageCode) {
      'zh' => strings.displayLanguageZhHans,
      'en' => strings.displayLanguageEnglish,
      _ => strings.displayLanguageSystem,
    };
  }

  String _displayModeLabel(AppLocalizations strings) {
    final raw = settings.displayModeRaw;
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
      currentLocale: locale,
    );
    if (next == null) {
      return;
    }
    final nextLocale = next.followSystem ? null : next.locale;
    if (locale?.languageCode == nextLocale?.languageCode &&
        ((locale != null) == (nextLocale != null))) {
      return;
    }
    await onApplyLocale(nextLocale);
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final presetWidth = (MediaQuery.of(context).size.width - 96) / 3;

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SettingsGroup(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                strings.displayThemeTitle,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.primary,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SegmentedButton<ThemeMode>(
                segments: [
                  ButtonSegment<ThemeMode>(
                    value: ThemeMode.light,
                    label: Text(strings.displayThemeLight),
                    icon: const Icon(Icons.light_mode_outlined),
                  ),
                  ButtonSegment<ThemeMode>(
                    value: ThemeMode.dark,
                    label: Text(strings.displayThemeDark),
                    icon: const Icon(Icons.dark_mode_outlined),
                  ),
                  ButtonSegment<ThemeMode>(
                    value: ThemeMode.system,
                    label: Text(strings.displayThemeSystem),
                    icon: const Icon(Icons.settings_suggest_outlined),
                  ),
                ],
                selected: {settings.themeMode},
                onSelectionChanged: (selection) {
                  unawaited(
                    onApply(settings.copyWith(themeMode: selection.first)),
                  );
                },
                showSelectedIcon: false,
              ),
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            SwitchListTile(
              value: settings.oledPureBlack,
              title: Text(strings.displayPureBlackTitle),
              subtitle: Text(strings.displayPureBlackSubtitle),
              onChanged: (value) {
                unawaited(onApply(settings.copyWith(oledPureBlack: value)));
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
                      currentDisplayModeRaw: settings.displayModeRaw,
                      onDisplayModeChanged: (displayModeRaw) {
                        return onApply(
                          settings.copyWith(displayModeRaw: displayModeRaw),
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
              value: settings.dynamicColor,
              title: Text(strings.displayDynamicColorTitle),
              subtitle: Text(strings.displayDynamicColorSubtitle),
              onChanged: (value) {
                unawaited(onApply(settings.copyWith(dynamicColor: value)));
              },
            ),
            const Divider(height: 1, indent: 56),
            SwitchListTile(
              secondary: const Icon(Icons.format_paint_outlined),
              value: settings.comicDetailDynamicColor,
              title: Text(strings.displayComicDynamicColorTitle),
              subtitle: Text(strings.displayComicDynamicColorSubtitle),
              onChanged: (value) {
                unawaited(
                  onApply(settings.copyWith(comicDetailDynamicColor: value)),
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
                  final selected = settings.presetIndex == index;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    width: presetWidth,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        unawaited(
                          onApply(settings.copyWith(presetIndex: index)),
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
