import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/services/hazuki_source_service.dart';
import 'package:hazuki/widgets/widgets.dart';
import 'network_logs_formatter.dart';

class LogsAppBarExportButton extends StatefulWidget {
  const LogsAppBarExportButton({super.key});

  @override
  State<LogsAppBarExportButton> createState() => _LogsAppBarExportButtonState();
}

class _LogsAppBarExportButtonState extends State<LogsAppBarExportButton> {
  static const MethodChannel _mediaChannel = MethodChannel(
    'hazuki.comics/media',
  );

  bool _exporting = false;

  String _buildSuggestedFileName(String prefix) {
    final now = DateTime.now();
    final yyyy = now.year.toString().padLeft(4, '0');
    final mm = now.month.toString().padLeft(2, '0');
    final dd = now.day.toString().padLeft(2, '0');
    final hh = now.hour.toString().padLeft(2, '0');
    final mi = now.minute.toString().padLeft(2, '0');
    final ss = now.second.toString().padLeft(2, '0');
    return 'hazuki_${prefix}_logs_$yyyy$mm${dd}_$hh$mi$ss.json';
  }

  Future<void> _saveLogsFile({
    required String prefix,
    required String content,
  }) async {
    final savedUri = await _mediaChannel.invokeMethod<String>('saveTextFile', {
      'suggestedFileName': _buildSuggestedFileName(prefix),
      'content': content,
    });
    if (!mounted) {
      return;
    }
    if (savedUri != null && savedUri.isNotEmpty) {
      unawaited(
        showHazukiPrompt(context, l10n(context).logsApplicationExportSuccess),
      );
    }
  }

  Future<void> _exportApplicationLogs() async {
    final debugInfo = await HazukiSourceService.instance
        .collectApplicationDebugInfo()
        .timeout(const Duration(seconds: 10));
    final prettyText = const JsonEncoder.withIndent('  ').convert(debugInfo);
    await _saveLogsFile(prefix: 'application', content: prettyText);
  }

  Future<void> _exportReaderLogs() async {
    final debugInfo = await HazukiSourceService.instance
        .collectReaderDebugInfo()
        .timeout(const Duration(seconds: 10));
    final prettyText = const JsonEncoder.withIndent('  ').convert(debugInfo);
    await _saveLogsFile(prefix: 'reader', content: prettyText);
  }

  Future<void> _exportNetworkLogs() async {
    final debugInfo = await HazukiSourceService.instance
        .collectNetworkDebugInfo()
        .timeout(const Duration(seconds: 10));
    if (!mounted) {
      return;
    }
    final prettyText = NetworkLogsFormatter(
      context,
    ).buildExportText(source: debugInfo);
    await _saveLogsFile(prefix: 'network', content: prettyText);
  }

  Future<void> _handleExport({required int tabIndex}) async {
    if (_exporting) {
      return;
    }
    setState(() {
      _exporting = true;
    });
    final strings = l10n(context);
    try {
      switch (tabIndex) {
        case 0:
          await _exportNetworkLogs();
          break;
        case 2:
          await _exportReaderLogs();
          break;
        case 1:
        default:
          await _exportApplicationLogs();
          break;
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      unawaited(
        showHazukiPrompt(context, strings.logsApplicationExportFailed(e)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _exporting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = l10n(context);
    final controller = DefaultTabController.maybeOf(context);
    if (controller == null) {
      return const SizedBox.shrink();
    }
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final tabIndex = controller.index;
        final exportKey = switch (tabIndex) {
          0 => 'network_logs_export_visible',
          1 => 'app_logs_export_visible',
          2 => 'reader_logs_export_visible',
          _ => 'logs_export_visible',
        };
        return IconButton(
          key: ValueKey<String>(exportKey),
          tooltip: strings.logsApplicationExportTooltip,
          onPressed: _exporting
              ? null
              : () => _handleExport(tabIndex: tabIndex),
          icon: _exporting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_alt_rounded),
        );
      },
    );
  }
}
