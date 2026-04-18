import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app.dart';
import '../../l10n/app_localizations.dart';
import '../../services/cloud_sync_service.dart';
import '../../widgets/widgets.dart';
import 'settings_group.dart';

class CloudSyncPage extends StatefulWidget {
  const CloudSyncPage({super.key});

  @override
  State<CloudSyncPage> createState() => _CloudSyncPageState();
}

class _CloudSyncPageState extends State<CloudSyncPage> {
  final _urlController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _passwordVisible = false;
  bool _enabled = false;
  bool _loading = true;
  bool _saving = false;
  bool _syncing = false;
  bool _checkingConnectivity = false;
  CloudSyncConnectionStatus? _status;

  @override
  void initState() {
    super.initState();
    unawaited(_loadConfig());
  }

  @override
  void dispose() {
    _urlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    final config = await CloudSyncService.instance.loadConfig();
    if (!mounted) {
      return;
    }
    final strings = AppLocalizations.of(context)!;
    setState(() {
      _enabled = config.enabled;
      _urlController.text = config.url;
      _usernameController.text = config.username;
      _passwordController.text = config.password;
      _loading = false;
      if (!config.enabled || !config.isComplete) {
        _status = CloudSyncConnectionStatus(
          ok: false,
          message: config.enabled
              ? strings.cloudSyncStatusIncomplete
              : strings.cloudSyncStatusDisabled,
          checkedAt: DateTime.now(),
        );
      }
    });
    if (config.enabled && config.isComplete) {
      unawaited(_checkConnectivityOnce(config));
    }
  }

  CloudSyncConfig _buildConfig() {
    return CloudSyncConfig(
      enabled: _enabled,
      url: _urlController.text.trim(),
      username: _usernameController.text.trim(),
      password: _passwordController.text,
    );
  }

  Future<void> _checkConnectivityOnce(CloudSyncConfig config) async {
    if (_checkingConnectivity) {
      return;
    }
    setState(() {
      _checkingConnectivity = true;
    });
    try {
      final status = await CloudSyncService.instance.testConnection(
        configOverride: config,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _status = status;
      });
    } finally {
      if (mounted) {
        setState(() {
          _checkingConnectivity = false;
        });
      }
    }
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }
    final config = _buildConfig();
    final uri = Uri.tryParse(config.url);
    final urlValid =
        uri != null && uri.hasScheme && config.url.trim().isNotEmpty;
    final strings = AppLocalizations.of(context)!;
    if (config.enabled && !config.isComplete) {
      unawaited(
        showHazukiPrompt(
          context,
          strings.cloudSyncIncompleteConfig,
          isError: true,
        ),
      );
      return;
    }
    if (config.enabled && !urlValid) {
      unawaited(
        showHazukiPrompt(context, strings.cloudSyncInvalidUrl, isError: true),
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      await CloudSyncService.instance.saveConfig(config);
      CloudSyncConnectionStatus status;
      if (config.enabled && config.isComplete) {
        status = await CloudSyncService.instance.testConnection(
          configOverride: config,
        );
      } else {
        status = CloudSyncConnectionStatus(
          ok: false,
          message: config.enabled
              ? strings.cloudSyncStatusIncomplete
              : strings.cloudSyncStatusDisabled,
          checkedAt: DateTime.now(),
        );
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _status = status;
      });
      unawaited(showHazukiPrompt(context, strings.cloudSyncConfigSaved));
    } catch (e) {
      if (!mounted) {
        return;
      }
      unawaited(
        showHazukiPrompt(
          context,
          strings.cloudSyncSaveFailed('$e'),
          isError: true,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _uploadBackup() async {
    if (_syncing) {
      return;
    }
    final config = _buildConfig();
    final strings = AppLocalizations.of(context)!;
    if (!config.enabled || !config.isComplete) {
      unawaited(
        showHazukiPrompt(
          context,
          strings.cloudSyncNeedCompleteConfig,
          isError: true,
        ),
      );
      return;
    }

    setState(() {
      _syncing = true;
    });
    try {
      await CloudSyncService.instance.uploadBackup(configOverride: config);
      final status = await CloudSyncService.instance.testConnection(
        configOverride: config,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _status = status;
      });
      unawaited(showHazukiPrompt(context, strings.cloudSyncUploadCompleted));
    } catch (e) {
      if (!mounted) {
        return;
      }
      unawaited(
        showHazukiPrompt(
          context,
          strings.cloudSyncUploadFailed('$e'),
          isError: true,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _syncing = false;
        });
      }
    }
  }

  Future<void> _restoreBackup() async {
    if (_syncing) {
      return;
    }
    final config = _buildConfig();
    final strings = AppLocalizations.of(context)!;
    if (!config.enabled || !config.isComplete) {
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
    if (confirmed != true) {
      return;
    }

    setState(() {
      _syncing = true;
    });
    try {
      final result = await CloudSyncService.instance.restoreLatestBackup(
        configOverride: config,
      );
      if (!mounted) {
        return;
      }
      final applyResult = await HazukiAppControllerScope.of(
        context,
      ).applyCloudSyncRestore(result);
      final status = await CloudSyncService.instance.testConnection(
        configOverride: config,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _status = status;
      });
      final message = StringBuffer(strings.cloudSyncRestoreCompleted);
      if (result.skippedKeys.isNotEmpty) {
        message.write('\n${strings.cloudSyncRestoreSkippedPlatformSettings}');
      }
      if (applyResult.sourceNeedsRestart) {
        message.write('\n${strings.cloudSyncRestoreSourceRestartRequired}');
      }
      unawaited(showHazukiPrompt(context, message.toString()));
    } catch (e) {
      if (!mounted) {
        return;
      }
      unawaited(
        showHazukiPrompt(
          context,
          strings.cloudSyncRestoreFailed('$e'),
          isError: true,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _syncing = false;
        });
      }
    }
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
    if (_loading) {
      return Scaffold(
        appBar: hazukiFrostedAppBar(
          context: context,
          title: Text(strings.cloudSyncTitle),
        ),
        body: const HazukiSettingsPageBody(
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final status = _status;
    final statusText = !_enabled
        ? strings.cloudSyncStatusDisabled
        : _checkingConnectivity
        ? strings.commonLoading
        : status == null
        ? strings.cloudSyncStatusUnchecked
        : '${status.ok ? strings.cloudSyncStatusConnected : strings.cloudSyncStatusDisconnected}\n${status.message}';
    final statusColor = !_enabled
        ? Theme.of(context).colorScheme.outline
        : _checkingConnectivity
        ? Theme.of(context).colorScheme.primary
        : status == null
        ? Theme.of(context).colorScheme.outline
        : status.ok
        ? Colors.green
        : Theme.of(context).colorScheme.error;
    final controlsEnabled = _enabled && !_saving && !_syncing;

    return Scaffold(
      appBar: hazukiFrostedAppBar(
        context: context,
        title: Text(strings.cloudSyncTitle),
      ),
      body: HazukiSettingsPageBody(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            _buildGroup(
              context,
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.cloud_sync_outlined),
                  value: _enabled,
                  title: Text(strings.cloudSyncEnabledTitle),
                  subtitle: Text(strings.cloudSyncEnabledSubtitle),
                  onChanged: (value) {
                    setState(() {
                      _enabled = value;
                      if (!value) {
                        _status = CloudSyncConnectionStatus(
                          ok: false,
                          message: strings.cloudSyncStatusDisabled,
                          checkedAt: DateTime.now(),
                        );
                      }
                    });
                  },
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeInOutCubic,
                  child: !_enabled
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: 16),
                              TextField(
                                controller: _urlController,
                                enabled: controlsEnabled,
                                decoration: InputDecoration(
                                  labelText: 'URL',
                                  border: const OutlineInputBorder(),
                                  helperText: strings.cloudSyncUrlHelper,
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _usernameController,
                                enabled: controlsEnabled,
                                decoration: InputDecoration(
                                  labelText: strings.cloudSyncUsernameLabel,
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _passwordController,
                                enabled: controlsEnabled,
                                obscureText: !_passwordVisible,
                                decoration: InputDecoration(
                                  labelText: strings.cloudSyncPasswordLabel,
                                  border: const OutlineInputBorder(),
                                  suffixIcon: IconButton(
                                    onPressed: () {
                                      setState(() {
                                        _passwordVisible = !_passwordVisible;
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
                                          color: statusColor.withValues(
                                            alpha: 0.7,
                                          ),
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      alignment: Alignment.center,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      child: Text(
                                        statusText,
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: statusColor,
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
                                        child: _saving
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
                                      icon: const Icon(Icons.restore_outlined),
                                      label: Text(strings.cloudSyncRestore),
                                    ),
                                  ),
                                ],
                              ),
                              if (_syncing) ...[
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
        ),
      ),
    );
  }
}
