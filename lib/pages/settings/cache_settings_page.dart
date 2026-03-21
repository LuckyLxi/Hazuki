part of '../../main.dart';

class CacheSettingsPage extends StatefulWidget {
  const CacheSettingsPage({super.key});

  @override
  State<CacheSettingsPage> createState() => _CacheSettingsPageState();
}

class _CacheSettingsPageState extends State<CacheSettingsPage> {
  bool _loading = true;
  int _maxBytes = 400 * 1024 * 1024;
  int _usedBytes = 0;
  String _autoCleanMode = 'size_overflow';

  @override
  void initState() {
    super.initState();
    unawaited(_loadCacheStatus());
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) {
      return '0 MB';
    }
    final mb = bytes / 1024 / 1024;
    if (mb < 1024) {
      return '${mb.toStringAsFixed(0)} MB';
    }
    final gb = mb / 1024;
    return '${gb.toStringAsFixed(2)} GB';
  }

  Future<void> _loadCacheStatus() async {
    setState(() {
      _loading = true;
    });

    try {
      final status = await HazukiSourceService.instance.getImageCacheStatus();
      if (!mounted) {
        return;
      }
      setState(() {
        _maxBytes = (status['maxBytes'] as int?) ?? (400 * 1024 * 1024);
        _usedBytes = (status['usedBytes'] as int?) ?? 0;
        _autoCleanMode =
            (status['autoCleanMode'] as String?) ?? 'size_overflow';
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _chooseCacheMaxSize() async {
    const presets = <(String label, int mb)>[
      ('默认 400MB', 400),
      ('轻量 600MB', 600),
      ('均衡 1024MB', 1024),
      ('重度 2048MB', 2048),
    ];

    final controller = TextEditingController();
    var selectedMb = (_maxBytes / 1024 / 1024).round();

    final result = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 8,
                  bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      '设置缓存最大容量',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('最低 400MB，可选择预设或自定义输入'),
                    const SizedBox(height: 10),
                    ...presets.map(
                      (preset) => ListTile(
                        onTap: () {
                          setSheetState(() {
                            selectedMb = preset.$2;
                            controller.clear();
                          });
                        },
                        leading: Icon(
                          selectedMb == preset.$2
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                        ),
                        title: Text(preset.$1),
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: controller,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '自定义（MB）',
                        hintText: '例如 1024',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        final parsed = int.tryParse(value.trim());
                        if (parsed == null) {
                          return;
                        }
                        setSheetState(() {
                          selectedMb = parsed;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () {
                        Navigator.pop(sheetContext, selectedMb);
                      },
                      child: const Text('确定'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result == null) {
      return;
    }

    final normalizedMb = result < 400 ? 400 : result;
    final bytes = normalizedMb * 1024 * 1024;
    await HazukiSourceService.instance.setImageCacheMaxBytes(bytes);
    await _loadCacheStatus();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('缓存上限已设为 ${normalizedMb}MB')));
  }

  Future<void> _chooseAutoCleanMode() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        var selected = _autoCleanMode;
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      '缓存自动清理',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ListTile(
                      onTap: () {
                        setSheetState(() {
                          selected = 'size_overflow';
                        });
                      },
                      leading: Icon(
                        selected == 'size_overflow'
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                      ),
                      title: const Text('超过上限自动清理'),
                      subtitle: const Text('按最旧缓存优先删除，直到低于上限'),
                    ),
                    ListTile(
                      onTap: () {
                        setSheetState(() {
                          selected = 'seven_days';
                        });
                      },
                      leading: Icon(
                        selected == 'seven_days'
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                      ),
                      title: const Text('每七天清理一次'),
                      subtitle: const Text('删除 7 天前缓存文件'),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: () => Navigator.pop(sheetContext, selected),
                      child: const Text('确定'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result == null) {
      return;
    }

    await HazukiSourceService.instance.setImageCacheAutoCleanMode(result);
    await _loadCacheStatus();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result == 'seven_days' ? '已设为每七天清理一次' : '已设为超过上限自动清理'),
      ),
    );
  }

  Future<void> _clearCacheNow() async {
    final confirm = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '关闭',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (ctx, anim1, anim2) {
        return AlertDialog(
          title: const Text('清理缓存'),
          content: const Text('确定要清理所有图片缓存吗？此操作不可逆。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('确定清理'),
            ),
          ],
        );
      },
      transitionBuilder: (ctx, anim, secondaryAnim, child) {
        return FadeTransition(
          opacity: anim,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.9, end: 1.0).animate(
              CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
            ),
            child: child,
          ),
        );
      },
    );

    if (confirm != true || !mounted) {
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      await HazukiSourceService.instance.clearImageCache();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('缓存清理成功')));
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('清理失败：$e')));
    } finally {
      if (mounted) {
        await _loadCacheStatus();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: hazukiFrostedAppBar(context: context, title: const Text('缓存设置')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                ListTile(
                  leading: const Icon(Icons.sd_storage_outlined),
                  title: const Text('缓存大小'),
                  subtitle: Text(
                    '当前 ${_formatBytes(_usedBytes)} / 上限 ${_formatBytes(_maxBytes)}',
                  ),
                  onTap: _chooseCacheMaxSize,
                ),
                ListTile(
                  leading: const Icon(Icons.auto_delete_outlined),
                  title: const Text('缓存自动清理'),
                  subtitle: Text(
                    _autoCleanMode == 'seven_days' ? '每七天清理一次' : '超过上限自动清理',
                  ),
                  onTap: _chooseAutoCleanMode,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(
                    Icons.delete_outline,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  title: Text(
                    '立即清理缓存',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  subtitle: const Text('清空本地下载的所有图片缓存，释放存储空间'),
                  onTap: _clearCacheNow,
                ),
              ],
            ),
    );
  }
}
