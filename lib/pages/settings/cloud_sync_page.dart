part of '../../main.dart';

class CloudSyncPage extends StatefulWidget {
  const CloudSyncPage({super.key});

  @override
  State<CloudSyncPage> createState() => _CloudSyncPageState();
}

class _CloudSyncPageState extends State<CloudSyncPage> {
  final _urlController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _enabled = false;
  bool _loading = true;
  bool _saving = false;
  bool _syncing = false;
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
    setState(() {
      _enabled = config.enabled;
      _urlController.text = config.url;
      _usernameController.text = config.username;
      _passwordController.text = config.password;
      _loading = false;
    });
  }

  CloudSyncConfig _buildConfig() {
    return CloudSyncConfig(
      enabled: _enabled,
      url: _urlController.text.trim(),
      username: _usernameController.text.trim(),
      password: _passwordController.text,
    );
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }
    final config = _buildConfig();
    final uri = Uri.tryParse(config.url);
    final urlValid =
        uri != null && uri.hasScheme && config.url.trim().isNotEmpty;
    final strings = l10n(context);
    if (config.enabled && !config.isComplete) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.cloudSyncIncompleteConfig)),
      );
      return;
    }
    if (config.enabled && !urlValid) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.cloudSyncInvalidUrl)));
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      await CloudSyncService.instance.saveConfig(config);
      CloudSyncConnectionStatus? status;
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.cloudSyncConfigSaved)));
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.cloudSyncSaveFailed('$e'))),
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
    final strings = l10n(context);
    if (!config.enabled || !config.isComplete) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.cloudSyncNeedCompleteConfig)),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.cloudSyncUploadCompleted)));
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.cloudSyncUploadFailed('$e'))),
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
    final strings = l10n(context);
    if (!config.enabled || !config.isComplete) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.cloudSyncNeedCompleteConfig)),
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
      await CloudSyncService.instance.restoreLatestBackup(
        configOverride: config,
      );
      final status = await CloudSyncService.instance.testConnection(
        configOverride: config,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _status = status;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.cloudSyncRestoreCompleted)),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.cloudSyncRestoreFailed('$e'))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _syncing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = l10n(context);
    if (_loading) {
      return Scaffold(
        appBar: hazukiFrostedAppBar(
          context: context,
          title: Text(strings.cloudSyncTitle),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final status = _status;
    final statusText = status == null
        ? strings.cloudSyncStatusUnchecked
        : '${status.ok ? strings.cloudSyncStatusConnected : strings.cloudSyncStatusDisconnected}\n${status.message}';
    final statusColor = status == null
        ? Theme.of(context).colorScheme.outline
        : status.ok
        ? Colors.green
        : Theme.of(context).colorScheme.error;

    return Scaffold(
      appBar: hazukiFrostedAppBar(
        context: context,
        title: Text(strings.cloudSyncTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            value: _enabled,
            title: Text(strings.cloudSyncEnabledTitle),
            subtitle: Text(strings.cloudSyncEnabledSubtitle),
            onChanged: (value) {
              setState(() {
                _enabled = value;
              });
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _urlController,
            enabled: !_saving && !_syncing,
            decoration: InputDecoration(
              labelText: 'URL',
              border: const OutlineInputBorder(),
              helperText: strings.cloudSyncUrlHelper,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _usernameController,
            enabled: !_saving && !_syncing,
            decoration: InputDecoration(
              labelText: strings.cloudSyncUsernameLabel,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            enabled: !_saving && !_syncing,
            obscureText: true,
            decoration: InputDecoration(
              labelText: strings.cloudSyncPasswordLabel,
              border: const OutlineInputBorder(),
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
                      color: statusColor.withValues(alpha: 0.7),
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    statusText,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: statusColor),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: (_saving || _syncing) ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
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
                  onPressed: (_saving || _syncing) ? null : _uploadBackup,
                  icon: const Icon(Icons.cloud_upload_outlined),
                  label: Text(strings.cloudSyncUpload),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: (_saving || _syncing) ? null : _restoreBackup,
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
    );
  }
}
