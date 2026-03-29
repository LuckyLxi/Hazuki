import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/app.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/widgets.dart';

class OtherSettingsPage extends StatefulWidget {
  const OtherSettingsPage({super.key});

  @override
  State<OtherSettingsPage> createState() => _OtherSettingsPageState();
}

class _OtherSettingsPageState extends State<OtherSettingsPage> {
  bool _autoCheckInEnabled = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_loadSettings());
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) {
      return;
    }
    setState(() {
      _autoCheckInEnabled =
          prefs.getBool(hazukiAutoCheckInEnabledPreferenceKey) ?? false;
      _loading = false;
    });
  }

  Future<void> _toggleAutoCheckIn(bool value) async {
    setState(() => _autoCheckInEnabled = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(hazukiAutoCheckInEnabledPreferenceKey, value);
  }

  Widget _buildGroup(BuildContext context, {required List<Widget> children}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: hazukiFrostedAppBar(
        context: context,
        title: Text(strings.otherTitle),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _buildGroup(
                  context,
                  children: [
                    SwitchListTile(
                      secondary: const Icon(Icons.event_available_outlined),
                      title: Text(strings.otherAutoCheckInTitle),
                      subtitle: Text(strings.otherAutoCheckInSubtitle),
                      value: _autoCheckInEnabled,
                      onChanged: _toggleAutoCheckIn,
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}
