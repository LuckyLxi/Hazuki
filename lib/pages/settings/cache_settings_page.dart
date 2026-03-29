import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../services/hazuki_source_service.dart';
import '../../widgets/widgets.dart';

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
    final strings = AppLocalizations.of(context)!;
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
    unawaited(
      showHazukiPrompt(context, strings.cacheLimitUpdated('$normalizedMb')),
    );
  }

  Future<void> _chooseAutoCleanMode() async {
    final strings = AppLocalizations.of(context)!;
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
    unawaited(
      showHazukiPrompt(
        context,
        result == 'seven_days'
            ? strings.cacheAutoCleanSevenDaysApplied
            : strings.cacheAutoCleanOverflowApplied,
      ),
    );
  }

  Future<void> _clearCacheNow() async {
    final strings = AppLocalizations.of(context)!;
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
      unawaited(showHazukiPrompt(context, strings.cacheCleared));
    } catch (e) {
      if (!mounted) {
        return;
      }
      unawaited(
        showHazukiPrompt(
          context,
          strings.cacheClearFailed('$e'),
          isError: true,
        ),
      );
    } finally {
      if (mounted) {
        await _loadCacheStatus();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    final double usageRatio = _maxBytes > 0
        ? (_usedBytes / _maxBytes).clamp(0.0, 1.0)
        : 0.0;
    final isUsageHigh = usageRatio > 0.9;
    final usageColor = isUsageHigh ? colorScheme.error : colorScheme.primary;

    return Scaffold(
      appBar: hazukiFrostedAppBar(
        context: context,
        title: Text(strings.cacheSettingsTitle),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Container(
                    padding: const EdgeInsets.all(24.0),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(24.0),
                      border: Border.all(
                        color: colorScheme.outlineVariant
                            .withValues(alpha: 0.5),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.sd_storage_rounded,
                                color: usageColor, size: 24),
                            const SizedBox(width: 8),
                            Text(
                              strings.cacheSizeTitle,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _formatBytes(_usedBytes).split(' ').first,
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w700,
                                color: colorScheme.onSurface,
                                height: 1.0,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4.0),
                              child: Text(
                                _formatBytes(_usedBytes).split(' ').last,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4.0),
                              child: Text(
                                '/ ${_formatBytes(_maxBytes)}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8.0),
                          child: LinearProgressIndicator(
                            value: usageRatio,
                            minHeight: 8,
                            backgroundColor: colorScheme.surfaceContainerHighest,
                            valueColor: AlwaysStoppedAnimation<Color>(usageColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.settings_overscan_outlined),
                  title: Text(strings.cacheMaxSizeTitle),
                  subtitle: Text(strings.cacheMaxSizeHint),
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
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: Divider(
                    height: 1,
                    color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                ListTile(
                  leading: Icon(
                    Icons.delete_sweep_outlined,
                    color: colorScheme.error,
                  ),
                  title: Text(
                    strings.cacheClearNowTitle,
                    style: TextStyle(
                      color: colorScheme.error,
                      fontWeight: FontWeight.w500,
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
