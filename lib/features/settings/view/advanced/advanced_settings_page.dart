import 'package:flutter/material.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/services/software_update/software_update_service.dart';
import 'package:hazuki/shared/ui_flags.dart';
import 'package:hazuki/widgets/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'advanced_settings_content.dart';
import '../settings_group.dart';

class AdvancedSettingsPage extends StatefulWidget {
  const AdvancedSettingsPage({
    super.key,
    required this.logsPageBuilder,
    required this.comicSourceEditorPageBuilder,
    required this.restoreComicSource,
    required this.sourceService,
    required this.softwareUpdateService,
  });

  final WidgetBuilder logsPageBuilder;
  final WidgetBuilder comicSourceEditorPageBuilder;
  final Future<bool> Function(BuildContext context) restoreComicSource;
  final SourceRuntimeGateway sourceService;
  final SoftwareUpdateService softwareUpdateService;

  @override
  State<AdvancedSettingsPage> createState() => _AdvancedSettingsPageState();
}

class _AdvancedSettingsPageState extends State<AdvancedSettingsPage> {
  SourceRuntimeGateway get _sourceService => widget.sourceService;
  SoftwareUpdateService get _softwareUpdateService =>
      widget.softwareUpdateService;
  bool _noImageMode = false;
  bool _softwareLogCaptureEnabled = false;
  bool _hasCustomEditedSource = false;
  SoftwareUpdateSource _softwareUpdateSource = SoftwareUpdateSource.jsDelivr;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _sourceService.addListener(_handleSourceChanged);
    _loadSettings();
  }

  @override
  void dispose() {
    _sourceService.removeListener(_handleSourceChanged);
    super.dispose();
  }

  void _handleSourceChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final hasCustomEditedSource = await _sourceService
        .hasCustomEditedActiveSource();
    final softwareLogCaptureEnabled = await _sourceService
        .loadSoftwareLogCaptureEnabled();
    final softwareUpdateSource = await _softwareUpdateService
        .loadUpdateSource();
    if (!mounted) {
      return;
    }
    setState(() {
      _noImageMode = prefs.getBool(hazukiNoImageModePreferenceKey) ?? false;
      _softwareLogCaptureEnabled = softwareLogCaptureEnabled;
      _hasCustomEditedSource = hasCustomEditedSource;
      _softwareUpdateSource = softwareUpdateSource;
      _loading = false;
    });
  }

  Future<void> _toggleNoImageMode(bool value) async {
    setState(() => _noImageMode = value);
    await setHazukiNoImageMode(value);
  }

  Future<void> _toggleSoftwareLogCaptureEnabled(bool value) async {
    setState(() => _softwareLogCaptureEnabled = value);
    await _sourceService.setSoftwareLogCaptureEnabled(value);
  }

  Future<void> _setSoftwareUpdateSource(SoftwareUpdateSource value) async {
    setState(() => _softwareUpdateSource = value);
    await _softwareUpdateService.setUpdateSource(value);
  }

  Future<void> _refreshCustomEditedSourceState() async {
    final hasCustomEditedSource = await _sourceService
        .hasCustomEditedActiveSource();
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

  Future<void> _clearCopyMangaDeviceInfo() async {
    final strings = AppLocalizations.of(context)!;
    try {
      await _sourceService.clearCopyMangaDeviceInfo();
      if (!mounted) {
        return;
      }
      await showHazukiPrompt(context, strings.advancedCopyMangaDeviceCleared);
    } catch (error) {
      if (!mounted) {
        return;
      }
      await showHazukiPrompt(
        context,
        strings.lineSaveFailed('$error'),
        isError: true,
      );
    }
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
          softwareUpdateSource: _softwareUpdateSource,
          hasCustomEditedSource: _hasCustomEditedSource,
          showCopyMangaSettings: _sourceService.isActiveCopyMangaSource,
          logsPageBuilder: widget.logsPageBuilder,
          onToggleNoImageMode: _toggleNoImageMode,
          onToggleSoftwareLogCaptureEnabled: _toggleSoftwareLogCaptureEnabled,
          onSoftwareUpdateSourceChanged: _setSoftwareUpdateSource,
          onOpenComicSourceEditor: _openComicSourceEditor,
          onRestoreComicSource: _restoreComicSource,
          onClearCopyMangaDeviceInfo: _clearCopyMangaDeviceInfo,
        ),
      ),
    );
  }
}
