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
    final urlValid = uri != null && uri.hasScheme && config.url.trim().isNotEmpty;
    if (config.enabled && !config.isComplete) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请填写完整 URL、Username、Password')));
      return;
    }
    if (config.enabled && !urlValid) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('URL 格式无效，请包含 http/https')));
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
          message: config.enabled ? '配置不完整' : '已关闭',
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
      ).showSnackBar(const SnackBar(content: Text('云同步配置已保存')));
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('保存失败: $e')));
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
    if (!config.enabled || !config.isComplete) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先开启云同步并保存完整配置')));
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
      ).showSnackBar(const SnackBar(content: Text('上传备份完成')));
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('上传失败: $e')));
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
    if (!config.enabled || !config.isComplete) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先开启云同步并保存完整配置')));
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('恢复备份'),
          content: const Text('是否覆盖本地文件并恢复云端最新备份？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('覆盖恢复'),
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
      await CloudSyncService.instance.restoreLatestBackup(configOverride: config);
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
      ).showSnackBar(const SnackBar(content: Text('恢复备份完成，已覆盖本地数据')));
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('恢复失败: $e')));
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
    if (_loading) {
      return Scaffold(
        appBar: hazukiFrostedAppBar(context: context, title: const Text('云同步')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final status = _status;
    final statusText = status == null
        ? '未检测'
        : '${status.ok ? '已连接' : '未连接'}\n${status.message}';
    final statusColor = status == null
        ? Theme.of(context).colorScheme.outline
        : status.ok
        ? Colors.green
        : Theme.of(context).colorScheme.error;

    return Scaffold(
      appBar: hazukiFrostedAppBar(context: context, title: const Text('云同步')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            value: _enabled,
            title: const Text('云同步'),
            subtitle: const Text('开启后可上传与恢复云端备份'),
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
            decoration: const InputDecoration(
              labelText: 'URL',
              border: OutlineInputBorder(),
              helperText: '程序会自动拼接 /HazukiSync，无需手动填写',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _usernameController,
            enabled: !_saving && !_syncing,
            decoration: const InputDecoration(
              labelText: 'Username',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            enabled: !_saving && !_syncing,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Password',
              border: OutlineInputBorder(),
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
                    border: Border.all(color: statusColor.withValues(alpha: 0.7)),
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
                        : const Text('保存'),
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
                  label: const Text('上传备份'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: (_saving || _syncing) ? null : _restoreBackup,
                  icon: const Icon(Icons.restore_outlined),
                  label: const Text('恢复备份'),
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
