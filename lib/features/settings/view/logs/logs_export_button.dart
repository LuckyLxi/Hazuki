import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/widgets/widgets.dart';
import 'logs_tabs.dart';

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
    final suggestedFileName = _buildSuggestedFileName(prefix);
    final savedUri = Platform.isWindows
        ? await _saveLogsFileOnWindows(
            suggestedFileName: suggestedFileName,
            content: content,
          )
        : await _mediaChannel.invokeMethod<String>('saveTextFile', {
            'suggestedFileName': suggestedFileName,
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

  Future<String?> _saveLogsFileOnWindows({
    required String suggestedFileName,
    required String content,
  }) async {
    final userProfile = Platform.environment['USERPROFILE']?.trim();
    final initialDirectory = userProfile == null || userProfile.isEmpty
        ? null
        : '$userProfile/Downloads'.replaceAll('\\', '/');
    const jsonTypeGroup = XTypeGroup(
      label: 'JSON',
      extensions: <String>['json'],
    );
    final saveLocation = await getSaveLocation(
      acceptedTypeGroups: const <XTypeGroup>[jsonTypeGroup],
      initialDirectory: initialDirectory,
      suggestedName: suggestedFileName,
    );
    final savePath = saveLocation?.path;
    if (savePath == null || savePath.trim().isEmpty) {
      return null;
    }
    final file = File(savePath);
    final parent = file.parent;
    if (!await parent.exists()) {
      await parent.create(recursive: true);
    }
    await file.writeAsString(content, flush: true);
    return file.path;
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
      final debugInfo = await collectVisibleLogsForIndex(
        tabIndex,
      ).timeout(const Duration(seconds: 10));
      final content = const JsonEncoder.withIndent('  ').convert(debugInfo);
      final type = (debugInfo['type'] ?? 'logs').toString();
      await _saveLogsFile(prefix: type, content: content);
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
        final exportKey = 'logs_export_visible_$tabIndex';
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
