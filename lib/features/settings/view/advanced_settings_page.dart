import 'package:flutter/material.dart';
import 'package:hazuki/app/app.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/services/hazuki_source_service.dart';
import 'package:hazuki/widgets/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'advanced/advanced_settings_content.dart';
import 'settings_group.dart';

class AdvancedSettingsPage extends StatefulWidget {
  const AdvancedSettingsPage({
    super.key,
    required this.logsPageBuilder,
    required this.comicSourceEditorPageBuilder,
    required this.restoreComicSource,
  });

  final WidgetBuilder logsPageBuilder;
  final WidgetBuilder comicSourceEditorPageBuilder;
  final Future<bool> Function(BuildContext context) restoreComicSource;

  @override
  State<AdvancedSettingsPage> createState() => _AdvancedSettingsPageState();
}

class _AdvancedSettingsPageState extends State<AdvancedSettingsPage> {
  bool _noImageMode = false;
  bool _softwareLogCaptureEnabled = false;
  bool _hasCustomEditedSource = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final hasCustomEditedSource = await HazukiSourceService.instance
        .hasCustomEditedJmSource();
    final softwareLogCaptureEnabled = await HazukiSourceService.instance
        .loadSoftwareLogCaptureEnabled();
    if (!mounted) {
      return;
    }
    setState(() {
      _noImageMode = prefs.getBool(hazukiNoImageModePreferenceKey) ?? false;
      _softwareLogCaptureEnabled = softwareLogCaptureEnabled;
      _hasCustomEditedSource = hasCustomEditedSource;
      _loading = false;
    });
  }

  Future<void> _toggleNoImageMode(bool value) async {
    setState(() => _noImageMode = value);
    await setHazukiNoImageMode(value);
  }

  Future<void> _toggleSoftwareLogCaptureEnabled(bool value) async {
    setState(() => _softwareLogCaptureEnabled = value);
    await HazukiSourceService.instance.setSoftwareLogCaptureEnabled(value);
  }

  Future<void> _refreshCustomEditedSourceState() async {
    final hasCustomEditedSource = await HazukiSourceService.instance
        .hasCustomEditedJmSource();
    if (!mounted) {
      return;
    }
    setState(() {
      _hasCustomEditedSource = hasCustomEditedSource;
    });
  }

  Future<void> _openComicSourceEditor() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: widget.comicSourceEditorPageBuilder),
    );
    if (!mounted) {
      return;
    }
    await _refreshCustomEditedSourceState();
  }

  Future<void> _restoreComicSource() async {
    final restored = await widget.restoreComicSource(context);
    if (!mounted || !restored) {
      return;
    }
    await _refreshCustomEditedSourceState();
    if (!mounted) {
      return;
    }
    final strings = AppLocalizations.of(context)!;
    await showHazukiPrompt(context, strings.advancedRestoreSourceSuccess);
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: hazukiFrostedAppBar(
        context: context,
        title: Text(strings.advancedTitle),
      ),
      body: HazukiSettingsPageBody(
        child: AdvancedSettingsContent(
          loading: _loading,
          noImageMode: _noImageMode,
          softwareLogCaptureEnabled: _softwareLogCaptureEnabled,
          hasCustomEditedSource: _hasCustomEditedSource,
          logsPageBuilder: widget.logsPageBuilder,
          onToggleNoImageMode: _toggleNoImageMode,
          onToggleSoftwareLogCaptureEnabled: _toggleSoftwareLogCaptureEnabled,
          onOpenComicSourceEditor: _openComicSourceEditor,
          onRestoreComicSource: _restoreComicSource,
        ),
      ),
    );
  }
}
