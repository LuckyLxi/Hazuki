import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hazuki/app/app.dart';
import 'package:hazuki/features/settings/state/cloud_sync_controller.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/services/cloud_sync_service.dart';
import 'package:hazuki/widgets/widgets.dart';
import '../settings_group.dart';

class CloudSyncPage extends StatefulWidget {
  const CloudSyncPage({super.key, required this.service});

  final CloudSyncService service;

  @override
  State<CloudSyncPage> createState() => _CloudSyncPageState();
}

class _CloudSyncPageState extends State<CloudSyncPage> {
  late final CloudSyncController _controller;
  bool _passwordVisible = false;

  @override
  void initState() {
    super.initState();
    _controller = CloudSyncController(service: widget.service);
    unawaited(_controller.loadConfig());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final strings = AppLocalizations.of(context)!;
    if (_controller.enabled) {
      if (!_controller.isConfigComplete) {
        unawaited(
          showHazukiPrompt(
            context,
            strings.cloudSyncIncompleteConfig,
            isError: true,
          ),
        );
        return;
      }
      final url = _controller.urlController.text.trim();
      final uri = Uri.tryParse(url);
      if (uri == null || !uri.hasScheme || url.isEmpty) {
        unawaited(
          showHazukiPrompt(context, strings.cloudSyncInvalidUrl, isError: true),
        );
        return;
      }
    }

    try {
      await _controller.saveConfig();
      if (!mounted) return;
      unawaited(showHazukiPrompt(context, strings.cloudSyncConfigSaved));
    } catch (e) {
      if (!mounted) return;
      unawaited(
        showHazukiPrompt(
          context,
          strings.cloudSyncSaveFailed('$e'),
          isError: true,
        ),
      );
    }
  }

  Future<void> _uploadBackup() async {
    final strings = AppLocalizations.of(context)!;
    if (!_controller.enabled || !_controller.isConfigComplete) {
      unawaited(
        showHazukiPrompt(
          context,
          strings.cloudSyncNeedCompleteConfig,
          isError: true,
        ),
      );
      return;
    }

    try {
      await _controller.uploadBackup();
      if (!mounted) return;
      unawaited(showHazukiPrompt(context, strings.cloudSyncUploadCompleted));
    } catch (e) {
      if (!mounted) return;
      unawaited(
        showHazukiPrompt(
          context,
          strings.cloudSyncUploadFailed('$e'),
          isError: true,
        ),
      );
    }
  }

  Future<void> _restoreBackup() async {
    final strings = AppLocalizations.of(context)!;
    if (!_controller.enabled || !_controller.isConfigComplete) {
      unawaited(
        showHazukiPrompt(
          context,
          strings.cloudSyncNeedCompleteConfig,
          isError: true,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(strings.cloudSyncRestoreTitle),
          content: Text(strings.cloudSyncRestoreContent),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(strings.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(strings.cloudSyncRestoreConfirm),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    try {
      final outcome = await _controller.restoreBackup(
        applyRestore: (result) =>
            HazukiAppControllerScope.of(context).applyCloudSyncRestore(result),
      );
      if (!mounted) return;
      final message = StringBuffer(strings.cloudSyncRestoreCompleted);
      if (outcome.skippedPlatformSettings) {
        message.write('\n${strings.cloudSyncRestoreSkippedPlatformSettings}');
      }
      if (outcome.sourceNeedsRestart) {
        message.write('\n${strings.cloudSyncRestoreSourceRestartRequired}');
      }
      unawaited(showHazukiPrompt(context, message.toString()));
    } catch (e) {
      if (!mounted) return;
      unawaited(
        showHazukiPrompt(
          context,
          strings.cloudSyncRestoreFailed('$e'),
          isError: true,
        ),
      );
    }
  }

  Widget _buildGroup(BuildContext context, {required List<Widget> children}) {
    return SettingsGroup(children: children);
  }

  ({String text, Color color}) _resolveStatusDisplay(
    BuildContext context,
    AppLocalizations strings,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    if (!_controller.enabled) {
      return (
        text: strings.cloudSyncStatusDisabled,
        color: colorScheme.outline,
      );
    }
    if (_controller.checkingConnectivity) {
      return (text: strings.commonLoading, color: colorScheme.primary);
    }
    if (!_controller.isConfigComplete) {
      return (
        text: strings.cloudSyncStatusIncomplete,
        color: colorScheme.outline,
      );
    }
    final status = _controller.status;
    if (status == null) {
      return (
        text: strings.cloudSyncStatusUnchecked,
        color: colorScheme.outline,
      );
    }
    final headline = status.ok
        ? strings.cloudSyncStatusConnected
        : strings.cloudSyncStatusDisconnected;
    return (
      text: '$headline\n${status.message}',
      color: status.ok ? Colors.green : colorScheme.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: hazukiFrostedAppBar(
        context: context,
        title: Text(strings.cloudSyncTitle),
      ),
      body: HazukiSettingsPageBody(
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            if (_controller.loading) {
              return const Center(child: CircularProgressIndicator());
            }

            final display = _resolveStatusDisplay(context, strings);
            final controlsEnabled =
                _controller.enabled &&
                !_controller.saving &&
                !_controller.syncing;

            return ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _buildGroup(
                  context,
                  children: [
                    SwitchListTile(
                      secondary: const Icon(Icons.cloud_sync_outlined),
                      value: _controller.enabled,
                      title: Text(strings.cloudSyncEnabledTitle),
                      subtitle: Text(strings.cloudSyncEnabledSubtitle),
                      onChanged: (value) => _controller.setEnabled(value),
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 240),
                      curve: Curves.easeInOutCubic,
                      child: !_controller.enabled
                          ? const SizedBox.shrink()
                          : Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const SizedBox(height: 16),
                                  TextField(
                                    controller: _controller.urlController,
                                    enabled: controlsEnabled,
                                    decoration: InputDecoration(
                                      labelText: 'URL',
                                      border: const OutlineInputBorder(),
                                      helperText: strings.cloudSyncUrlHelper,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: _controller.usernameController,
                                    enabled: controlsEnabled,
                                    decoration: InputDecoration(
                                      labelText: strings.cloudSyncUsernameLabel,
                                      border: const OutlineInputBorder(),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: _controller.passwordController,
                                    enabled: controlsEnabled,
                                    obscureText: !_passwordVisible,
                                    decoration: InputDecoration(
                                      labelText: strings.cloudSyncPasswordLabel,
                                      border: const OutlineInputBorder(),
                                      suffixIcon: IconButton(
                                        onPressed: () {
                                          setState(() {
                                            _passwordVisible =
                                                !_passwordVisible;
                                          });
                                        },
                                        icon: Icon(
                                          _passwordVisible
                                              ? Icons.visibility_off_outlined
                                              : Icons.visibility_outlined,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        flex: 1,
                                        child: Container(
                                          height: 52,
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: display.color.withValues(
                                                alpha: 0.7,
                                              ),
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          alignment: Alignment.center,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                          ),
                                          child: Text(
                                            display.text,
                                            textAlign: TextAlign.center,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: display.color,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        flex: 2,
                                        child: SizedBox(
                                          height: 52,
                                          child: FilledButton(
                                            onPressed: controlsEnabled
                                                ? _save
                                                : null,
                                            child: _controller.saving
                                                ? const SizedBox(
                                                    width: 18,
                                                    height: 18,
                                                    child:
                                                        CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                        ),
                                                  )
                                                : Text(strings.cloudSyncSave),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: controlsEnabled
                                              ? _uploadBackup
                                              : null,
                                          icon: const Icon(
                                            Icons.cloud_upload_outlined,
                                          ),
                                          label: Text(strings.cloudSyncUpload),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: FilledButton.tonalIcon(
                                          onPressed: controlsEnabled
                                              ? _restoreBackup
                                              : null,
                                          icon: const Icon(
                                            Icons.restore_outlined,
                                          ),
                                          label: Text(strings.cloudSyncRestore),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (_controller.syncing) ...[
                                    const SizedBox(height: 12),
                                    const LinearProgressIndicator(),
                                  ],
                                ],
                              ),
                            ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
