import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/app.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/widgets.dart';
import 'settings_group.dart';

class LabSettingsPage extends StatefulWidget {
  const LabSettingsPage({super.key});

  @override
  State<LabSettingsPage> createState() => _LabSettingsPageState();
}

class _LabSettingsPageState extends State<LabSettingsPage> {
  bool _comicIdSearchEnhance = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) {
      return;
    }
    setState(() {
      _comicIdSearchEnhance =
          prefs.getBool(hazukiComicIdSearchEnhancePreferenceKey) ?? false;
      _loading = false;
    });
  }

  Future<void> _toggleComicIdSearchEnhance(bool value) async {
    setState(() => _comicIdSearchEnhance = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(hazukiComicIdSearchEnhancePreferenceKey, value);
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: hazukiFrostedAppBar(
        context: context,
        title: Text(strings.labTitle),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                SettingsGroup(
                  children: [
                    SwitchListTile(
                      secondary: const Icon(Icons.tag_outlined),
                      title: Text(strings.advancedComicIdSearchTitle),
                      subtitle: Text(strings.advancedComicIdSearchSubtitle),
                      value: _comicIdSearchEnhance,
                      onChanged: _toggleComicIdSearchEnhance,
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}
