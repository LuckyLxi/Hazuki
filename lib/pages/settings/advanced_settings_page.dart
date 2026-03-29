import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/app.dart';
import '../../l10n/app_localizations.dart';
import '../../services/hazuki_source_service.dart';
import '../../widgets/widgets.dart';
import 'advanced/advanced_settings_content.dart';

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
  static const _keyComicIdSearchEnhance = 'advanced_comic_id_search_enhance';

  bool _comicIdSearchEnhance = false;
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
      _comicIdSearchEnhance = prefs.getBool(_keyComicIdSearchEnhance) ?? false;
      _noImageMode = prefs.getBool(hazukiNoImageModePreferenceKey) ?? false;
      _softwareLogCaptureEnabled = softwareLogCaptureEnabled;
      _hasCustomEditedSource = hasCustomEditedSource;
      _loading = false;
    });
  }

  Future<void> _toggleComicIdSearchEnhance(bool value) async {
    setState(() => _comicIdSearchEnhance = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyComicIdSearchEnhance, value);
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
      body: AdvancedSettingsContent(
        loading: _loading,
        comicIdSearchEnhance: _comicIdSearchEnhance,
        noImageMode: _noImageMode,
        softwareLogCaptureEnabled: _softwareLogCaptureEnabled,
        hasCustomEditedSource: _hasCustomEditedSource,
        logsPageBuilder: widget.logsPageBuilder,
        onToggleComicIdSearchEnhance: _toggleComicIdSearchEnhance,
        onToggleNoImageMode: _toggleNoImageMode,
        onToggleSoftwareLogCaptureEnabled: _toggleSoftwareLogCaptureEnabled,
        onOpenComicSourceEditor: _openComicSourceEditor,
        onRestoreComicSource: _restoreComicSource,
      ),
    );
  }
}
