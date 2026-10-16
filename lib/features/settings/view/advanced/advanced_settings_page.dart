import 'package:flutter/material.dart';
import 'package:hazuki/shared/source_presentation.dart';
import 'package:hazuki/services/source/plugins/source_plugin_localization.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/services/software_update/software_update_service.dart';
import 'package:hazuki/shared/ui_flags.dart';
import 'package:hazuki/widgets/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'advanced_settings_content.dart';
import '../settings_group.dart';
import '../../support/other_settings_actions.dart';
import '../plugins/source_plugin_action_widgets.dart';

class AdvancedSettingsPage extends StatefulWidget {
  const AdvancedSettingsPage({
    super.key,
    required this.logsPageBuilder,
    required this.comicSourceEditorPageBuilder,
    required this.restoreComicSource,
    this.redownloadComicSource,
    required this.sourceService,
    required this.softwareUpdateService,
    this.sourcePlugins,
  });

  final WidgetBuilder logsPageBuilder;
  final WidgetBuilder comicSourceEditorPageBuilder;
  final Future<bool> Function(BuildContext context) restoreComicSource;
  final Future<bool> Function(BuildContext context)? redownloadComicSource;
  final SourceAdvancedGateway sourceService;
  final SoftwareUpdateService softwareUpdateService;
  final SourcePluginGateway? sourcePlugins;

  @override
  State<AdvancedSettingsPage> createState() => _AdvancedSettingsPageState();
}

class _AdvancedSettingsPageState extends State<AdvancedSettingsPage> {
  SourceAdvancedGateway get _sourceService => widget.sourceService;
  SoftwareUpdateService get _softwareUpdateService =>
      widget.softwareUpdateService;
  bool _noImageMode = false;
  bool _softwareLogCaptureEnabled = false;
  bool _hasSourceBackup = false;
  bool _autoSourceUpdateCheckEnabled = true;
  bool _autoSoftwareUpdateCheckEnabled = true;
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
      _refreshSourceBackupState();
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSourceBackup = await _sourceService.hasActiveSourceBackup();
    final softwareLogCaptureEnabled = await _sourceService
        .loadSoftwareLogCaptureEnabled();
    final softwareUpdateSource = await _softwareUpdateService
        .loadUpdateSource();
    final updateChecks = await OtherSettingsActions.loadUpdateCheckSettings();
    if (!mounted) {
      return;
    }
    setState(() {
      _noImageMode = prefs.getBool(hazukiNoImageModePreferenceKey) ?? false;
      _softwareLogCaptureEnabled = softwareLogCaptureEnabled;
      _hasSourceBackup = hasSourceBackup;
      _autoSourceUpdateCheckEnabled = updateChecks.source;
      _autoSoftwareUpdateCheckEnabled = updateChecks.software;
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

  Future<void> _toggleAutoSourceUpdateCheck(bool value) async {
    setState(() => _autoSourceUpdateCheckEnabled = value);
    await OtherSettingsActions.toggleAutoSourceUpdateCheck(context, value);
  }

  Future<void> _toggleAutoSoftwareUpdateCheck(bool value) async {
    setState(() => _autoSoftwareUpdateCheckEnabled = value);
    await OtherSettingsActions.toggleAutoSoftwareUpdateCheck(context, value);
  }

  Future<void> _refreshSourceBackupState() async {
    final hasSourceBackup = await _sourceService.hasActiveSourceBackup();
    if (!mounted) {
      return;
    }
    setState(() {
      _hasSourceBackup = hasSourceBackup;
    });
  }

  Future<void> _openComicSourceEditor() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: widget.comicSourceEditorPageBuilder),
    );
    if (!mounted) {
      return;
    }
    await _refreshSourceBackupState();
  }

  Future<void> _restoreComicSource() async {
    final restored = await widget.restoreComicSource(context);
    if (!mounted || !restored) {
      return;
    }
    await _refreshSourceBackupState();
    if (!mounted) {
      return;
    }
    final strings = AppLocalizations.of(context)!;
    await showHazukiPrompt(context, strings.advancedRestoreSourceSuccess);
  }

  Future<void> _redownloadComicSource() async {
    final restored = await widget.redownloadComicSource!(context);
    if (!mounted || !restored) return;
    await _refreshSourceBackupState();
    if (!mounted) return;
    await showHazukiPrompt(
      context,
      AppLocalizations.of(context)!.advancedRestoreSourceSuccess,
    );
  }

  Future<void> _runSourceDeviceAction(
    String sourceKey,
    SourcePluginButton button,
  ) async {
    final strings = AppLocalizations.of(context)!;
    try {
      final result = await widget.sourcePlugins!.runAction(
        sourceKey,
        button.action!,
      );
      if (!mounted) {
        return;
      }
      await showHazukiPrompt(
        context,
        localizeSourcePluginText(
          button.successMessage ?? result ?? button.title ?? button.id,
          Localizations.localeOf(context).toLanguageTag(),
          translation:
              widget.sourcePlugins!
                  .pluginFor(sourceKey)
                  ?.manifest
                  .translation ??
              const {},
        ),
      );
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
    final sourceKey =
        SourcePresentationScope.read(context)?.activeSourceKey ?? '';
    final deviceAction = activeSourceButton(
      context,
      'resetDeviceInfo',
      SourcePluginButtonLocation.advanced,
    );
    String buttonText(Object? value) => localizeSourcePluginText(
      value,
      Localizations.localeOf(context).toLanguageTag(),
      translation:
          widget.sourcePlugins?.pluginFor(sourceKey)?.manifest.translation ??
          const {},
    );
    return Scaffold(
      appBar: hazukiFrostedAppBar(
        context: context,
        title: Text(strings.advancedTitle),
      ),
      body: HazukiSettingsPageBody(
        child: AdvancedSettingsContent(
          footer: widget.sourcePlugins == null
              ? null
              : SourcePluginActionList(
                  gateway: widget.sourcePlugins!,
                  location: SourcePluginActionLocation.advanced,
                ),
          loading: _loading,
          noImageMode: _noImageMode,
          softwareLogCaptureEnabled: _softwareLogCaptureEnabled,
          autoSourceUpdateCheckEnabled: _autoSourceUpdateCheckEnabled,
          autoSoftwareUpdateCheckEnabled: _autoSoftwareUpdateCheckEnabled,
          softwareUpdateSource: _softwareUpdateSource,
          hasSourceBackup: _hasSourceBackup,
          onRedownloadComicSource:
              widget.redownloadComicSource != null &&
                  widget.sourcePlugins?.pluginFor(sourceKey)?.repository != null
              ? _redownloadComicSource
              : null,
          sourceDeviceAction:
              deviceAction == null || widget.sourcePlugins == null
              ? null
              : ListTile(
                  leading: const Icon(Icons.phonelink_erase_outlined),
                  title: Text(
                    buttonText(deviceAction.title ?? deviceAction.id),
                  ),
                  subtitle: deviceAction.subtitle == null
                      ? null
                      : Text(buttonText(deviceAction.subtitle)),
                  onTap: () => _runSourceDeviceAction(sourceKey, deviceAction),
                ),
          logsPageBuilder: widget.logsPageBuilder,
          onToggleNoImageMode: _toggleNoImageMode,
          onToggleSoftwareLogCaptureEnabled: _toggleSoftwareLogCaptureEnabled,
          onToggleAutoSourceUpdateCheck: _toggleAutoSourceUpdateCheck,
          onToggleAutoSoftwareUpdateCheck: _toggleAutoSoftwareUpdateCheck,
          onSoftwareUpdateSourceChanged: _setSoftwareUpdateSource,
          onOpenComicSourceEditor: _openComicSourceEditor,
          onRestoreComicSource: _restoreComicSource,
        ),
      ),
    );
  }
}
