import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/services/hazuki_source_service.dart';
import 'package:hazuki/widgets/widgets.dart';
import 'logs/logs_export_button.dart';
import 'logs/logs_tabs.dart';
import 'settings_group.dart';

class LogsPage extends StatefulWidget {
  const LogsPage({super.key});

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  int _clearEpoch = 0;

  Future<void> _copyCurrentLogs(TabController controller) async {
    final strings = l10n(context);
    try {
      final debugInfo = await collectVisibleLogsForIndex(
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
          return Scaffold(
            appBar: hazukiFrostedAppBar(
              context: context,
              title: Text(strings.advancedDebugTitle),
              actions: [
                const LogsAppBarExportButton(),
                IconButton(
                  tooltip: strings.logsFilterTitle,
                  onPressed: () => unawaited(_showTypeDialog(controller)),
                  icon: const Icon(Icons.filter_list_rounded),
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
                      key: ValueKey<String>('${spec.type}-$_clearEpoch'),
                      spec: spec,
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
