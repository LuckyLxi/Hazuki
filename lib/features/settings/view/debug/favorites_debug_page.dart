import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/widgets/widgets.dart';

import '../logs/logs_export_button.dart';
import '../logs/logs_tabs.dart';
import '../settings_group.dart';

class LogsPage extends StatelessWidget {
  const LogsPage({super.key, required this.debugGateway});

  final SourceDebugGateway debugGateway;

  void _dismissKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  Future<void> _copy(BuildContext context) async {
    _dismissKeyboard();
    try {
      final report = await debugGateway.collectAllDebugInfo().timeout(
        const Duration(seconds: 10),
      );
      if (context.mounted) await copyDebugReport(context, report);
    } catch (error) {
      if (context.mounted) {
        unawaited(
          showHazukiPrompt(
            context,
            l10n(context).logsCopyFailed(error),
            isError: true,
          ),
        );
      }
    }
  }

  Future<void> _clear(BuildContext context) async {
    _dismissKeyboard();
    final strings = l10n(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.logsClearTitle),
        content: Text(strings.logsClearContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(strings.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(strings.logsClearConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await debugGateway.clearCapturedLogs();
    if (context.mounted) {
      unawaited(showHazukiPrompt(context, strings.logsCleared));
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = l10n(context);
    return Scaffold(
      appBar: hazukiFrostedAppBar(
        context: context,
        title: Text(strings.logsAllTitle),
        actions: [
          LogsAppBarExportButton(
            collectDebugInfo: debugGateway.collectAllDebugInfo,
          ),
          PopupMenuButton<String>(
            tooltip: strings.logsMoreTooltip,
            onOpened: _dismissKeyboard,
            onSelected: (value) {
              if (value == 'clear') unawaited(_clear(context));
            },
            itemBuilder: (_) => [
              PopupMenuItem<String>(
                value: 'clear',
                child: Text(strings.logsClearTitle),
              ),
            ],
          ),
        ],
      ),
      body: HazukiSettingsPageBody(
        child: UnifiedLogsView(debugGateway: debugGateway),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: strings.favoritesDebugCopyTooltip,
        onPressed: () => unawaited(_copy(context)),
        child: const Icon(Icons.copy_outlined),
      ),
    );
  }
}

@Deprecated('Use LogsPage')
class FavoritesDebugPage extends LogsPage {
  const FavoritesDebugPage({super.key, required super.debugGateway});
}
