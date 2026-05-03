import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/services/hazuki_source_service.dart';
import 'package:hazuki/widgets/widgets.dart';
import 'logs/logs_export_button.dart';
import 'logs/logs_history_store.dart';
import 'logs/logs_tabs.dart';
import 'settings_group.dart';

class LogsPage extends StatefulWidget {
  const LogsPage({super.key});

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  static const LogsHistoryStore _historyStore = LogsHistoryStore();
  static const Object _liveLogsSelection = Object();

  int _clearEpoch = 0;
  List<LogsHistoryEntry> _historyEntries = const <LogsHistoryEntry>[];
  LogsHistoryEntry? _selectedHistoryEntry;

  @override
  void initState() {
    super.initState();
    unawaited(_loadHistoryAndSaveCurrentSnapshot());
  }

  Future<void> _loadHistoryAndSaveCurrentSnapshot() async {
    final loaded = await _historyStore.load();
    if (mounted) {
      setState(() {
        _historyEntries = loaded;
      });
    }

    final generatedAt = DateTime.now().toIso8601String();
    final logsByType = <String, Map<String, dynamic>>{};
    for (var i = 0; i < logsTabSpecs.length; i++) {
      final spec = logsTabSpecs[i];
      try {
        logsByType[spec.type] = await collectVisibleLogsForIndex(
          i,
        ).timeout(const Duration(seconds: 10));
      } catch (error) {
        logsByType[spec.type] = <String, dynamic>{
          'type': spec.type,
          'generatedAt': generatedAt,
          'logs': const <Map<String, dynamic>>[],
          'logStats': const <String, dynamic>{'keptCount': 0},
          'historySnapshotError': error.toString(),
        };
      }
    }

    final updated = await _historyStore.add(
      LogsHistoryEntry(
        id: generatedAt,
        generatedAt: generatedAt,
        logsByType: logsByType,
      ),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _historyEntries = updated;
    });
  }

  Future<Map<String, dynamic>> _collectDisplayedLogsForIndex(int index) async {
    final historyInfo = debugInfoForVisibleIndex(
      _selectedHistoryEntry?.logsByType,
      index,
    );
    if (historyInfo != null) {
      return historyInfo;
    }
    return collectVisibleLogsForIndex(index);
  }

  Future<void> _copyCurrentLogs(TabController controller) async {
    final strings = l10n(context);
    try {
      final debugInfo = await _collectDisplayedLogsForIndex(
        controller.index,
      ).timeout(const Duration(seconds: 10));
      final text = formatVisibleLogs(debugInfo);
      if (text.trim().isEmpty) {
        return;
      }
      await Clipboard.setData(ClipboardData(text: text));
      if (!mounted) {
        return;
      }
      unawaited(showHazukiPrompt(context, strings.logsCopied));
    } catch (e) {
      if (!mounted) {
        return;
      }
      unawaited(
        showHazukiPrompt(context, strings.logsCopyFailed(e), isError: true),
      );
    }
  }

  Future<void> _showTypeDialog(TabController controller) {
    final strings = l10n(context);
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: strings.dialogBarrierLabel,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        final theme = Theme.of(dialogContext);
        return SafeArea(
          child: Dialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 24,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            strings.logsFilterTitle,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: strings.commonCancel,
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TabBar(
                      controller: controller,
                      isScrollable: true,
                      tabs: [
                        for (final spec in logsTabSpecs)
                          Tab(
                            icon: Icon(spec.icon),
                            text: spec.titleBuilder(dialogContext),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1).animate(curved),
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.04),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          ),
        );
      },
    );
  }

  Future<void> _showHistoryDialog() async {
    final strings = l10n(context);
    final selected = await showGeneralDialog<Object>(
      context: context,
      barrierDismissible: true,
      barrierLabel: strings.dialogBarrierLabel,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        final theme = Theme.of(dialogContext);
        final colorScheme = theme.colorScheme;
        final entries = _historyEntries;
        return SafeArea(
          child: Dialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 24,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460, maxHeight: 560),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            strings.logsHistoryTitle,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: strings.commonCancel,
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const ClampingScrollPhysics(),
                        itemCount: entries.length + 1,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            final selected = _selectedHistoryEntry == null;
                            return Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () => Navigator.of(
                                  dialogContext,
                                ).pop(_liveLogsSelection),
                                child: Ink(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? colorScheme.secondaryContainer
                                        : colorScheme.surfaceContainerHighest
                                              .withValues(alpha: 0.42),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: selected
                                          ? colorScheme.secondary.withValues(
                                              alpha: 0.36,
                                            )
                                          : colorScheme.outlineVariant
                                                .withValues(alpha: 0.56),
                                    ),
                                  ),
                                  child: Text(
                                    strings.advancedDebugTitle,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: selected
                                          ? colorScheme.onSecondaryContainer
                                          : colorScheme.onSurface,
                                      fontWeight: selected
                                          ? FontWeight.w700
                                          : FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }
                          final entry = entries[index - 1];
                          final selected =
                              entry.id == _selectedHistoryEntry?.id;
                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () =>
                                  Navigator.of(dialogContext).pop(entry),
                              child: Ink(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? colorScheme.secondaryContainer
                                      : colorScheme.surfaceContainerHighest
                                            .withValues(alpha: 0.42),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: selected
                                        ? colorScheme.secondary.withValues(
                                            alpha: 0.36,
                                          )
                                        : colorScheme.outlineVariant.withValues(
                                            alpha: 0.56,
                                          ),
                                  ),
                                ),
                                child: Text(
                                  entry.generatedAt,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: selected
                                        ? colorScheme.onSecondaryContainer
                                        : colorScheme.onSurface,
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    if (entries.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: Text(
                          strings.logsHistoryEmpty,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1).animate(curved),
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.04),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          ),
        );
      },
    );
    if (!mounted || selected == null) {
      return;
    }
    if (identical(selected, _liveLogsSelection)) {
      setState(() {
        _selectedHistoryEntry = null;
      });
      return;
    }
    if (selected is! LogsHistoryEntry) {
      return;
    }
    setState(() {
      _selectedHistoryEntry = selected;
    });
  }

  Future<void> _confirmClearLogs() async {
    final strings = l10n(context);
    final confirm = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: strings.dialogBarrierLabel,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return AlertDialog(
          title: Text(strings.logsClearTitle),
          content: Text(strings.logsClearContent),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(strings.commonCancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(strings.logsClearConfirm),
            ),
          ],
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
    if (confirm != true || !mounted) {
      return;
    }
    HazukiSourceService.instance.facade.clearCapturedLogs();
    unawaited(showHazukiPrompt(context, strings.logsCleared));
    setState(() {
      _clearEpoch++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = l10n(context);
    return DefaultTabController(
      length: logsTabSpecs.length,
      child: Builder(
        builder: (context) {
          final controller = DefaultTabController.of(context);
          final selectedHistory = _selectedHistoryEntry;
          return Scaffold(
            appBar: hazukiFrostedAppBar(
              context: context,
              title: Text(
                selectedHistory?.generatedAt ?? strings.advancedDebugTitle,
              ),
              actions: [
                LogsAppBarExportButton(
                  collectDebugInfo: _collectDisplayedLogsForIndex,
                ),
                IconButton(
                  tooltip: strings.logsFilterTitle,
                  onPressed: () => unawaited(_showTypeDialog(controller)),
                  icon: const Icon(Icons.filter_list_rounded),
                ),
                IconButton(
                  tooltip: strings.logsHistoryTooltip,
                  onPressed: () => unawaited(_showHistoryDialog()),
                  icon: const Icon(Icons.history_rounded),
                ),
                PopupMenuButton<String>(
                  tooltip: strings.logsMoreTooltip,
                  onSelected: (value) {
                    if (value == 'clear') {
                      unawaited(_confirmClearLogs());
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem<String>(
                      value: 'clear',
                      child: Text(strings.logsClearTitle),
                    ),
                  ],
                ),
              ],
            ),
            body: HazukiSettingsPageBody(
              child: TabBarView(
                children: [
                  for (final spec in logsTabSpecs)
                    DebugLogsTab(
                      key: ValueKey<String>(
                        '${spec.type}-$_clearEpoch-${selectedHistory?.id ?? 'live'}',
                      ),
                      spec: spec,
                      debugInfoOverride: selectedHistory?.logsByType[spec.type],
                    ),
                ],
              ),
            ),
            floatingActionButton: FloatingActionButton(
              tooltip: strings.favoritesDebugCopyTooltip,
              onPressed: () => unawaited(_copyCurrentLogs(controller)),
              child: const Icon(Icons.copy_outlined),
            ),
          );
        },
      ),
    );
  }
}

@Deprecated('Use LogsPage')
class FavoritesDebugPage extends LogsPage {
  const FavoritesDebugPage({super.key});
}
