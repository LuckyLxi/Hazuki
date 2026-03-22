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

  Future<_LocaleDialogChoice?> _showLocaleDialog(BuildContext context) {
    return showGeneralDialog<_LocaleDialogChoice>(
      context: context,
      barrierDismissible: true,
      barrierLabel: l10n(context).dialogBarrierLabel,
      barrierColor: Colors.black45,
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        final strings = l10n(dialogContext);
        final colorScheme = Theme.of(dialogContext).colorScheme;
        final currentLanguageCode = _locale?.languageCode;

        Widget optionTile({
          required String title,
          required String subtitle,
          required bool selected,
          required VoidCallback onTap,
        }) {
          return InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(22),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(
                color: selected
                    ? colorScheme.primaryContainer
                    : colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: selected
                      ? colorScheme.primary
                      : colorScheme.outlineVariant.withValues(alpha: 0.45),
                  width: selected ? 1.6 : 1,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: Theme.of(dialogContext).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: selected
                                    ? colorScheme.onPrimaryContainer
                                    : colorScheme.onSurface,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: Theme.of(dialogContext).textTheme.bodySmall
                              ?.copyWith(
                                color: selected
                                    ? colorScheme.onPrimaryContainer
                                          .withValues(alpha: 0.82)
                                    : colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: selected
                          ? colorScheme.primary
                          : colorScheme.surface,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected
                            ? colorScheme.primary
                            : colorScheme.outlineVariant,
                      ),
                    ),
                    child: Icon(
                      selected
                          ? Icons.check_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 18,
                      color: selected
                          ? colorScheme.onPrimary
                          : colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return SafeArea(
          child: Center(
            child: Material(
              type: MaterialType.transparency,
              child: Container(
                width: 360,
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 28,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.displayLanguageTitle,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      strings.displayLanguageSubtitle,
                      style: Theme.of(dialogContext).textTheme.bodyMedium
                          ?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 16),
                    optionTile(
                      title: strings.displayLanguageSystem,
                      subtitle: 'Use device setting',
                      selected: _locale == null,
                      onTap: () => Navigator.of(dialogContext).pop(
                        const _LocaleDialogChoice.system(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    optionTile(
                      title: strings.displayLanguageZhHans,
                      subtitle: 'Simplified Chinese',
                      selected: currentLanguageCode == 'zh',
                      onTap: () => Navigator.of(dialogContext).pop(
                        const _LocaleDialogChoice.locale(Locale('zh')),
                      ),
                    ),
                    const SizedBox(height: 10),
                    optionTile(
                      title: strings.displayLanguageEnglish,
                      subtitle: 'English',
                      selected: currentLanguageCode == 'en',
                      onTap: () => Navigator.of(dialogContext).pop(
                        const _LocaleDialogChoice.locale(Locale('en')),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder:
          (dialogContext, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutBack,
              reverseCurve: Curves.easeInCubic,
            );
            return FadeTransition(
              opacity: curved,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.92, end: 1).animate(curved),
                child: child,
              ),
            );
          },
    );
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
              final next = await _showLocaleDialog(context);
              if (next == null) {
                return;
              }
              final nextLocale = next.followSystem ? null : next.locale;
              if (_locale?.languageCode == nextLocale?.languageCode &&
                  ((_locale != null) == (nextLocale != null))) {
                return;
              }
              await _applyLocale(nextLocale);
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

class _LocaleDialogChoice {
  const _LocaleDialogChoice.system()
    : followSystem = true,
      locale = null;

  const _LocaleDialogChoice.locale(this.locale) : followSystem = false;

  final bool followSystem;
  final Locale? locale;
}
