import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hazuki/shared/appearance/appearance_settings.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/widgets/sun_moon_icon.dart';
import 'display_mode_settings_page.dart';
import '../settings_group.dart';
import 'appearance_settings_locale_dialog.dart';
import 'appearance_favorite_layout_picker.dart';
import 'appearance_layout_option.dart';
import 'appearance_settings_widgets.dart';

class AppearanceSettingsContent extends StatefulWidget {
  const AppearanceSettingsContent({
    super.key,
    required this.settings,
    required this.locale,
    required this.onApply,
    required this.onApplyLocale,
    required this.debugGateway,
  });

  final AppearanceSettingsData settings;
  final Locale? locale;
  final AppearanceSettingsApplyCallback onApply;
  final Future<void> Function(Locale? locale) onApplyLocale;
  final SourceDebugGateway debugGateway;

  @override
  State<AppearanceSettingsContent> createState() =>
      _AppearanceSettingsContentState();
}

class _AppearanceSettingsContentState extends State<AppearanceSettingsContent> {
  final GlobalKey _themeIconKey = GlobalKey();
  final GlobalKey _themeModeSelectorKey = GlobalKey();
  ThemeMode? _pendingThemeMode;
  int _themeSelectionGeneration = 0;

  ThemeMode get _selectedThemeMode =>
      _pendingThemeMode ?? widget.settings.themeMode;

  void _logThemeUiEvent(
    String title, {
    String level = 'info',
    Map<String, Object?>? content,
  }) {
    widget.debugGateway.addApplicationLog(
      level: level,
      title: title,
      source: 'appearance_theme_ui',
      content: {
        'route': 'appearance_settings',
        'themeModeSetting': widget.settings.themeMode.name,
        'effectiveBrightness': Theme.of(context).brightness.name,
        ...?content,
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

  String _discoverSectionLayoutLabel(
    AppLocalizations strings,
    DiscoverSectionLayout layout,
  ) {
    return switch (layout) {
      DiscoverSectionLayout.horizontal =>
        strings.displayDiscoverLayoutHorizontal,
      DiscoverSectionLayout.list => strings.displayDiscoverLayoutList,
      DiscoverSectionLayout.grid2 => strings.displayDiscoverLayoutGrid2,
      DiscoverSectionLayout.grid3 => strings.displayDiscoverLayoutGrid3,
    };
  }

  Future<void> _handleDiscoverSectionLayoutTap(BuildContext context) async {
    final strings = AppLocalizations.of(context)!;
    final selected = await showModalBottomSheet<DiscoverSectionLayout>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        final colorScheme = Theme.of(sheetContext).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 16),
                  child: Text(
                    strings.displayDiscoverLayoutTitle,
                    style: Theme.of(sheetContext).textTheme.titleLarge,
                  ),
                ),
                GridView.count(
                  key: const ValueKey('discover-layout-picker-grid'),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 2.15,
                  children: [
                    for (final layout in DiscoverSectionLayout.values)
                      AppearanceLayoutOption(
                        icon: switch (layout) {
                          DiscoverSectionLayout.horizontal =>
                            Icons.view_carousel_outlined,
                          DiscoverSectionLayout.list =>
                            Icons.view_agenda_outlined,
                          DiscoverSectionLayout.grid2 =>
                            Icons.grid_view_rounded,
                          DiscoverSectionLayout.grid3 => Icons.apps_rounded,
                        },
                        label: _discoverSectionLayoutLabel(strings, layout),
                        selected:
                            widget.settings.discoverSectionLayout == layout,
                        colorScheme: colorScheme,
                        onTap: () => Navigator.of(sheetContext).pop(layout),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    if (selected == null || selected == widget.settings.discoverSectionLayout) {
      return;
    }
    await widget.onApply(
      widget.settings.copyWith(discoverSectionLayout: selected),
    );
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

  Future<void> _handleFavoriteLayoutTap() async {
    final selected = await showFavoriteLayoutPicker(
      context,
      selected: widget.settings.favoriteLayout,
    );
    if (!mounted ||
        selected == null ||
        selected == widget.settings.favoriteLayout) {
      return;
    }
    await widget.onApply(widget.settings.copyWith(favoriteLayout: selected));
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

  Rect? _themeModeSelectorRect() {
    final selectorContext = _themeModeSelectorKey.currentContext;
    final renderObject = selectorContext?.findRenderObject();
    if (renderObject is! RenderBox) {
      _logThemeUiEvent(
        'Theme mode selector bounds unavailable',
        level: 'warning',
        content: {'reason': 'selector_render_box_not_found'},
      );
      return null;
    }
    return renderObject.localToGlobal(Offset.zero) & renderObject.size;
  }

  Future<void> _applyThemeMode(ThemeMode mode) async {
    if (_selectedThemeMode == mode) {
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

    final generation = ++_themeSelectionGeneration;
    final currentMode = _selectedThemeMode;
    final targetBrightness = switch (mode) {
      ThemeMode.light => Brightness.light,
      ThemeMode.dark => Brightness.dark,
      ThemeMode.system => MediaQuery.platformBrightnessOf(context),
    };
    final waitsForThemeReveal =
        Theme.of(context).brightness != targetBrightness;
    setState(() {
      _pendingThemeMode = waitsForThemeReveal ? currentMode : mode;
    });

    try {
      await widget.onApply(
        widget.settings.copyWith(themeMode: mode),
        revealOrigin: _themeToggleOrigin(),
        revealSyncRegion: waitsForThemeReveal ? _themeModeSelectorRect() : null,
      );
    } finally {
      if (mounted && generation == _themeSelectionGeneration) {
        setState(() {
          _pendingThemeMode = null;
        });
      }
    }
  }

  Future<void> _applyPreset(int index) async {
    final settings = widget.settings;
    if (!settings.dynamicColor && settings.presetIndex == index) {
      return;
    }
    // 选择固定配色即退出壁纸取色。
    await widget.onApply(
      settings.copyWith(presetIndex: index, dynamicColor: false),
    );
  }

  Future<void> _applyWallpaperColor() async {
    if (widget.settings.dynamicColor) {
      return;
    }
    await widget.onApply(widget.settings.copyWith(dynamicColor: true));
  }

  Widget _buildThemeModeSelector({
    required AppLocalizations strings,
    required ColorScheme colorScheme,
  }) {
    // 缩略图按当前主色分别生成浅色/深色配色，确保与实际效果一致。
    final lightScheme = ColorScheme.fromSeed(
      seedColor: colorScheme.primary,
      brightness: Brightness.light,
    );
    final darkScheme = ColorScheme.fromSeed(
      seedColor: colorScheme.primary,
      brightness: Brightness.dark,
    );
    final options = [
      (ThemeMode.light, strings.displayThemeLight),
      (ThemeMode.dark, strings.displayThemeDark),
      (ThemeMode.system, strings.displayThemeSystem),
    ];
    return Padding(
      key: _themeModeSelectorKey,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Row(
        spacing: 10,
        children: [
          for (final (mode, label) in options)
            Expanded(
              child: AppearanceThemeModeCard(
                key: ValueKey('theme-mode-option-${mode.name}'),
                mode: mode,
                label: label,
                selected: _selectedThemeMode == mode,
                lightScheme: lightScheme,
                darkScheme: darkScheme,
                pureBlack: widget.settings.oledPureBlack,
                onTap: () => unawaited(_applyThemeMode(mode)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildColorPalette(AppLocalizations strings) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth = constraints.maxWidth / 5;
          return Wrap(
            runSpacing: 4,
            children: [
              SizedBox(
                width: itemWidth,
                child: AppearanceColorSwatch(
                  key: const ValueKey('theme-color-wallpaper'),
                  label: strings.displayWallpaperColorLabel,
                  icon: Icons.wallpaper_rounded,
                  selected: widget.settings.dynamicColor,
                  onTap: () => unawaited(_applyWallpaperColor()),
                ),
              ),
              for (var index = 0; index < kHazukiColorPresets.length; index++)
                SizedBox(
                  width: itemWidth,
                  child: AppearanceColorSwatch(
                    key: ValueKey('theme-color-preset-$index'),
                    label: kHazukiColorPresets[index].labelBuilder(strings),
                    color: kHazukiColorPresets[index].seedColor,
                    selected:
                        !widget.settings.dynamicColor &&
                        widget.settings.presetIndex == index,
                    onTap: () => unawaited(_applyPreset(index)),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSwitch({
    required IconData icon,
    required bool value,
    required String title,
    required String subtitle,
    required AppearanceSettingsData Function(bool value) update,
  }) {
    return SwitchListTile(
      secondary: Icon(icon),
      value: value,
      title: Text(title),
      subtitle: Text(subtitle),
      onChanged: (next) => unawaited(widget.onApply(update(next))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isWindows = theme.platform == TargetPlatform.windows;
    final settings = widget.settings;
    const divider = Divider(height: 1, indent: 56);

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        AppearanceSectionHeader(
          title: strings.displayThemeModeTitle,
          // 日月图标是主题切换扩散动画的起点。
          trailing: SizedBox(
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
        ),
        _buildThemeModeSelector(strings: strings, colorScheme: colorScheme),
        SettingsGroup(
          children: [
            _buildSwitch(
              icon: Icons.dark_mode_outlined,
              value: settings.oledPureBlack,
              title: strings.displayPureBlackTitle,
              subtitle: strings.displayPureBlackSubtitle,
              update: (value) => settings.copyWith(oledPureBlack: value),
            ),
          ],
        ),
        AppearanceSectionHeader(title: strings.displayThemeColorTitle),
        SettingsGroup(
          children: [
            _buildColorPalette(strings),
            divider,
            _buildSwitch(
              icon: Icons.format_paint_outlined,
              value: settings.comicDetailDynamicColor,
              title: strings.displayComicDynamicColorTitle,
              subtitle: strings.displayComicDynamicColorSubtitle,
              update: (value) =>
                  settings.copyWith(comicDetailDynamicColor: value),
            ),
          ],
        ),
        AppearanceSectionHeader(title: strings.displayInterfaceEffectsTitle),
        SettingsGroup(
          children: [
            _buildSwitch(
              icon: Icons.water_drop_outlined,
              value: settings.liquidGlassEnabled,
              title: strings.displayLiquidGlassTitle,
              subtitle: strings.displayLiquidGlassSubtitle,
              update: (value) => settings.copyWith(liquidGlassEnabled: value),
            ),
            divider,
            _buildSwitch(
              icon: Icons.splitscreen_outlined,
              value: settings.homeTabCutTransition,
              title: strings.displayHomeTabCutTransitionTitle,
              subtitle: strings.displayHomeTabCutTransitionSubtitle,
              update: (value) => settings.copyWith(homeTabCutTransition: value),
            ),
            divider,
            _buildSwitch(
              icon: Icons.font_download_outlined,
              value: settings.useSystemFont,
              title: strings.displaySystemFontTitle,
              subtitle: strings.displaySystemFontSubtitle,
              update: (value) => settings.copyWith(useSystemFont: value),
            ),
          ],
        ),
        AppearanceSectionHeader(title: strings.displayLayoutSectionTitle),
        SettingsGroup(
          children: [
            ListTile(
              leading: const Icon(Icons.view_quilt_outlined),
              title: Text(strings.displayDiscoverLayoutTitle),
              subtitle: Text(
                isWindows
                    ? strings.displayDiscoverLayoutAdaptiveWall
                    : _discoverSectionLayoutLabel(
                        strings,
                        settings.discoverSectionLayout,
                      ),
              ),
              trailing: isWindows
                  ? null
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 4,
                      children: [
                        AppearanceLayoutGlyph.discover(
                          settings.discoverSectionLayout,
                        ),
                        const Icon(Icons.chevron_right_rounded),
                      ],
                    ),
              onTap: isWindows
                  ? null
                  : () {
                      unawaited(_handleDiscoverSectionLayoutTap(context));
                    },
            ),
            divider,
            ListTile(
              key: const ValueKey('favorite-layout-setting'),
              leading: const Icon(Icons.collections_bookmark_outlined),
              title: Text(strings.displayFavoriteLayoutTitle),
              subtitle: Text(
                favoriteLayoutLabel(strings, settings.favoriteLayout),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 4,
                children: [
                  AppearanceLayoutGlyph.favorite(settings.favoriteLayout),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
              onTap: () => unawaited(_handleFavoriteLayoutTap()),
            ),
          ],
        ),
        AppearanceSectionHeader(
          title: strings.displayLanguageSystemSectionTitle,
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
            divider,
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
        const SizedBox(height: 24),
      ],
    );
  }
}
