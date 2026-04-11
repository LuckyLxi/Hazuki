import 'package:flutter/material.dart';

import '../../app/app.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/widgets.dart';
import 'appearance/appearance_settings_content.dart';
import 'settings_group.dart';

class AppearanceSettingsPage extends StatefulWidget {
  const AppearanceSettingsPage({
    super.key,
    required this.appearanceSettings,
    required this.onAppearanceChanged,
    required this.locale,
    required this.onLocaleChanged,
  });

  final AppearanceSettingsData appearanceSettings;
  final AppearanceSettingsApplyCallback onAppearanceChanged;
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

  @override
  void didUpdateWidget(covariant AppearanceSettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.appearanceSettings != widget.appearanceSettings) {
      _settings = widget.appearanceSettings;
    }
    if (oldWidget.locale != widget.locale) {
      _locale = widget.locale;
    }
  }

  Future<void> _apply(
    AppearanceSettingsData next, {
    Offset? revealOrigin,
  }) async {
    setState(() {
      _settings = next;
    });
    await widget.onAppearanceChanged(next, revealOrigin: revealOrigin);
  }

  Future<void> _applyLocale(Locale? locale) async {
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
        title: Text(strings.displayTitle),
      ),
      body: HazukiSettingsPageBody(
        child: AppearanceSettingsContent(
          settings: _settings,
          locale: _locale,
          onApply: _apply,
          onApplyLocale: _applyLocale,
        ),
      ),
    );
  }
}
