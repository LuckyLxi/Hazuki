import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hazuki/features/settings/state/cache_settings_controller.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/widgets/widgets.dart';
import 'settings_group.dart';

part 'cache_settings_widgets.dart';

class CacheSettingsPage extends StatefulWidget {
  const CacheSettingsPage({super.key, required this.sourceService});

  final SourceSettingsGateway sourceService;

  @override
  State<CacheSettingsPage> createState() => _CacheSettingsPageState();
}

class _CacheSettingsPageState extends State<CacheSettingsPage>
    with SingleTickerProviderStateMixin {
  late final CacheSettingsController _controller;
  late final AnimationController _entranceController;
  bool _clearCompleted = false;
  Timer? _clearCompletedTimer;

  @override
  void initState() {
    super.initState();
    _controller = CacheSettingsController(sourceService: widget.sourceService);
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    )..forward();
    unawaited(_controller.loadStatus());
  }

  @override
  void dispose() {
    _clearCompletedTimer?.cancel();
    _entranceController.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// 清理完成后在清理条目上短暂显示完成标记。
  void _flashClearCompleted() {
    _clearCompletedTimer?.cancel();
    setState(() => _clearCompleted = true);
    _clearCompletedTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _clearCompleted = false);
    });
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
    var selectedMb = (_controller.maxBytes / 1024 / 1024).round();

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

    final normalizedMb = await _controller.setMaxBytesFromMb(result);
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
        var selected = _controller.autoCleanMode;
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

    await _controller.setAutoCleanMode(result);
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

    try {
      await _controller.clearCache();
      if (!mounted) {
        return;
      }
      _flashClearCompleted();
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: hazukiFrostedAppBar(
        context: context,
        title: Text(strings.cacheSettingsTitle),
      ),
      body: HazukiSettingsPageBody(
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            final usedBytes = _controller.usedBytes;
            final clearing = _controller.clearing;

            return ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _CacheEntrance(
                  animation: _entranceController,
                  index: 0,
                  child: _CacheUsageCard(
                    title: strings.cacheSizeTitle,
                    initialized: _controller.initialized,
                    usedBytes: usedBytes,
                    maxBytes: _controller.maxBytes,
                  ),
                ),
                _CacheEntrance(
                  animation: _entranceController,
                  index: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _CacheSectionHeader(strings.cachePolicySectionTitle),
                      SettingsGroup(
                        children: [
                          _CacheSettingTile(
                            icon: Icons.settings_overscan_outlined,
                            title: strings.cacheMaxSizeTitle,
                            value: _formatCacheBytes(_controller.maxBytes),
                            onTap: _chooseCacheMaxSize,
                          ),
                          _CacheSettingTile(
                            icon: Icons.auto_delete_outlined,
                            title: strings.cacheAutoCleanTitle,
                            value: _controller.autoCleanMode == 'seven_days'
                                ? strings.cacheAutoCleanModeSummary
                                : strings.cacheAutoCleanModeOverflowSummary,
                            onTap: _chooseAutoCleanMode,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _CacheEntrance(
                  animation: _entranceController,
                  index: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _CacheSectionHeader(strings.cacheMaintenanceSectionTitle),
                      SettingsGroup(
                        children: [
                          _CacheClearTile(
                            title: strings.cacheClearNowTitle,
                            subtitle: usedBytes > 0
                                ? strings.cacheClearNowReleasable(
                                    _formatCacheBytes(usedBytes),
                                  )
                                : strings.cacheClearNowSubtitle,
                            busySubtitle: strings.cacheClearing,
                            completedSubtitle: strings.cacheCleared,
                            busy: clearing,
                            completed: _clearCompleted,
                            onTap: clearing ? null : _clearCacheNow,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
