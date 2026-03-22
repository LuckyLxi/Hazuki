part of '../../main.dart';

class AppearanceSettingsPage extends StatefulWidget {
  const AppearanceSettingsPage({
    super.key,
    required this.appearanceSettings,
    required this.onAppearanceChanged,
    required this.locale,
    required this.onLocaleChanged,
  });

  final AppearanceSettingsData appearanceSettings;
  final Future<void> Function(AppearanceSettingsData next) onAppearanceChanged;
  final Locale? locale;
  final Future<void> Function(Locale? locale) onLocaleChanged;

  @override
  State<AppearanceSettingsPage> createState() => _AppearanceSettingsPageState();
}

class _AppearanceSettingsPageState extends State<AppearanceSettingsPage> {
  late AppearanceSettingsData _settings;
  late Locale? _locale;

  @override
  void initState() {
    super.initState();
    _settings = widget.appearanceSettings;
    _locale = widget.locale;
  }

  Future<void> _apply(AppearanceSettingsData next) async {
    setState(() {
      _settings = next;
    });
    await widget.onAppearanceChanged(next);
  }

  Future<void> _applyLocale(Locale? locale) async {
    setState(() {
      _locale = locale;
    });
    await widget.onLocaleChanged(locale);
  }

  String _themeModeLabel(AppLocalizations strings) {
    return switch (_settings.themeMode) {
      ThemeMode.light => strings.displayThemeLight,
      ThemeMode.dark => strings.displayThemeDark,
      _ => strings.displayThemeSystem,
    };
  }

  String _localeLabel(AppLocalizations strings) {
    return switch (_locale?.languageCode) {
      'zh' => strings.displayLanguageZhHans,
      'en' => strings.displayLanguageEnglish,
      _ => strings.displayLanguageSystem,
    };
  }

  String _displayModeLabel(AppLocalizations strings) {
    final raw = _settings.displayModeRaw;
    if (raw == 'native:auto') {
      return strings.displayRefreshRateAuto;
    }
    if (raw.startsWith('native:')) {
      final id = raw.substring('native:'.length);
      return strings.displayRefreshRateSpecified(id);
    }
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    final strings = l10n(context);
    return Scaffold(
      appBar: hazukiFrostedAppBar(
        context: context,
        title: Text(strings.displayTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          ListTile(
            title: Text(strings.displayThemeTitle),
            subtitle: Text(_themeModeLabel(strings)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
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
              selected: {_settings.themeMode},
              onSelectionChanged: (selection) {
                final mode = selection.first;
                unawaited(_apply(_settings.copyWith(themeMode: mode)));
              },
              showSelectedIcon: false,
            ),
          ),
          const Divider(height: 1),
          ListTile(
            title: Text(strings.displayLanguageTitle),
            subtitle: Text(_localeLabel(strings)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final next = await showModalBottomSheet<Locale?>(
                context: context,
                builder: (sheetContext) {
                  final sheetStrings = l10n(sheetContext);
                  return SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          title: Text(sheetStrings.displayLanguageSystem),
                          onTap: () => Navigator.of(sheetContext).pop(),
                        ),
                        ListTile(
                          title: Text(sheetStrings.displayLanguageZhHans),
                          onTap: () => Navigator.of(
                            sheetContext,
                          ).pop(const Locale('zh')),
                        ),
                        ListTile(
                          title: Text(sheetStrings.displayLanguageEnglish),
                          onTap: () => Navigator.of(
                            sheetContext,
                          ).pop(const Locale('en')),
                        ),
                      ],
                    ),
                  );
                },
              );
              if (_locale?.languageCode == next?.languageCode &&
                  ((_locale != null) == (next != null))) {
                return;
              }
              await _applyLocale(next);
            },
          ),
          const Divider(height: 1),
          ListTile(
            title: Text(strings.displayRefreshRateTitle),
            subtitle: Text(_displayModeLabel(strings)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => DisplayModeSettingsPage(
                    currentDisplayModeRaw: _settings.displayModeRaw,
                    onDisplayModeChanged: (displayModeRaw) {
                      return _apply(
                        _settings.copyWith(displayModeRaw: displayModeRaw),
                      );
                    },
                  ),
                ),
              );
            },
          ),
          SwitchListTile(
            value: _settings.oledPureBlack,
            title: Text(strings.displayPureBlackTitle),
            subtitle: Text(strings.displayPureBlackSubtitle),
            onChanged: (value) {
              unawaited(_apply(_settings.copyWith(oledPureBlack: value)));
            },
          ),
          SwitchListTile(
            value: _settings.dynamicColor,
            title: Text(strings.displayDynamicColorTitle),
            subtitle: Text(strings.displayDynamicColorSubtitle),
            onChanged: (value) {
              unawaited(_apply(_settings.copyWith(dynamicColor: value)));
            },
          ),
          SwitchListTile(
            value: _settings.comicDetailDynamicColor,
            title: Text(strings.displayComicDynamicColorTitle),
            subtitle: Text(strings.displayComicDynamicColorSubtitle),
            onChanged: (value) {
              unawaited(
                _apply(_settings.copyWith(comicDetailDynamicColor: value)),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Text(
              strings.displayColorSchemeTitle,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: List<Widget>.generate(kHazukiColorPresets.length, (
                index,
              ) {
                final preset = kHazukiColorPresets[index];
                final selected = _settings.presetIndex == index;
                return SizedBox(
                  width: (MediaQuery.of(context).size.width - 52) / 3,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: selected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outlineVariant,
                        width: selected ? 2 : 1,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 10,
                      ),
                    ),
                    onPressed: () {
                      unawaited(_apply(_settings.copyWith(presetIndex: index)));
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: preset.seedColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          preset.labelBuilder(strings),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
