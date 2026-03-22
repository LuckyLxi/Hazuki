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
    final strings = l10n(context);
    final presets = <(String label, int mb)>[
      (strings.cachePresetDefault, 400),
      (strings.cachePresetLite, 600),
      (strings.cachePresetBalanced, 1024),
      (strings.cachePresetHeavy, 2048),
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
                    Text(
                      strings.cacheMaxSizeTitle,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(strings.cacheMaxSizeHint),
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
                      decoration: InputDecoration(
                        labelText: strings.cacheCustomMbLabel,
                        hintText: strings.cacheCustomMbHint,
                        border: const OutlineInputBorder(),
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
                      child: Text(strings.commonConfirm),
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(strings.cacheLimitUpdated('$normalizedMb'))),
    );
  }

  Future<void> _chooseAutoCleanMode() async {
    final strings = l10n(context);
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
                    Text(
                      strings.cacheAutoCleanTitle,
                      style: const TextStyle(
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
                      title: Text(strings.cacheAutoCleanOverflowTitle),
                      subtitle: Text(strings.cacheAutoCleanOverflowSubtitle),
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
                      title: Text(strings.cacheAutoCleanSevenDaysTitle),
                      subtitle: Text(strings.cacheAutoCleanSevenDaysSubtitle),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: () => Navigator.pop(sheetContext, selected),
                      child: Text(strings.commonConfirm),
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
        content: Text(
          result == 'seven_days'
              ? strings.cacheAutoCleanSevenDaysApplied
              : strings.cacheAutoCleanOverflowApplied,
        ),
      ),
    );
  }

  Future<void> _clearCacheNow() async {
    final strings = l10n(context);
    final confirm = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: strings.cacheClearBarrierLabel,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (ctx, anim1, anim2) {
        return AlertDialog(
          title: Text(strings.cacheClearTitle),
          content: Text(strings.cacheClearContent),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(strings.commonCancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(strings.cacheClearConfirm),
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
      ).showSnackBar(SnackBar(content: Text(strings.cacheCleared)));
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.cacheClearFailed('$e'))));
    } finally {
      if (mounted) {
        await _loadCacheStatus();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = l10n(context);
    return Scaffold(
      appBar: hazukiFrostedAppBar(
        context: context,
        title: Text(strings.cacheSettingsTitle),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                ListTile(
                  leading: const Icon(Icons.sd_storage_outlined),
                  title: Text(strings.cacheSizeTitle),
                  subtitle: Text(
                    strings.cacheSizeSummary(
                      _formatBytes(_usedBytes),
                      _formatBytes(_maxBytes),
                    ),
                  ),
                  onTap: _chooseCacheMaxSize,
                ),
                ListTile(
                  leading: const Icon(Icons.auto_delete_outlined),
                  title: Text(strings.cacheAutoCleanTitle),
                  subtitle: Text(
                    _autoCleanMode == 'seven_days'
                        ? strings.cacheAutoCleanModeSummary
                        : strings.cacheAutoCleanModeOverflowSummary,
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
                    strings.cacheClearNowTitle,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  subtitle: Text(strings.cacheClearNowSubtitle),
                  onTap: _clearCacheNow,
                ),
              ],
            ),
    );
  }
}
