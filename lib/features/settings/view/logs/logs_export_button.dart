import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/services/logging/app_log_event.dart';
import 'package:hazuki/services/logging/app_log_sanitizer.dart';
import 'package:hazuki/services/logging/app_log_text_formatter.dart';
import 'package:hazuki/widgets/widgets.dart';

Future<AppLogSanitization?> showLogSanitizationDialog(BuildContext context) {
  final strings = l10n(context);
  return showDialog<AppLogSanitization>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(strings.logsSensitiveTitle),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(strings.logsSensitiveMessage),
              const SizedBox(height: 14),
              _SanitizationOption(
                icon: Icons.shield_outlined,
                title: strings.logsSensitiveHideAll,
                onTap: () => Navigator.pop(
                  dialogContext,
                  AppLogSanitization.hideAllSensitive,
                ),
              ),
              _SanitizationOption(
                icon: Icons.person_outline,
                title: strings.logsSensitiveHideCredentials,
                onTap: () => Navigator.pop(
                  dialogContext,
                  AppLogSanitization.keepAccountInfo,
                ),
              ),
              _SanitizationOption(
                icon: Icons.warning_amber_rounded,
                title: strings.logsSensitiveKeepAll,
                subtitle: strings.logsSensitiveKeepAllWarning,
                isWarning: true,
                onTap: () => Navigator.pop(
                  dialogContext,
                  AppLogSanitization.keepEverything,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(strings.commonCancel),
        ),
      ],
    ),
  );
}

Future<AppLogSanitization?> resolveLogSanitization(
  BuildContext context,
  Object? value,
) {
  if (!const AppLogSanitizer().containsSensitiveInformation(value)) {
    return Future.value(AppLogSanitization.keepEverything);
  }
  return showLogSanitizationDialog(context);
}

String formatDebugReportAsLog(
  Map<String, dynamic> report,
  AppLogSanitization sanitization,
) {
  final rawLogs = report['logs'];
  final events = rawLogs is List
      ? rawLogs.map(AppLogEvent.fromJson).whereType<AppLogEvent>()
      : const Iterable<AppLogEvent>.empty();
  return const AppLogTextFormatter().format(
    events: events,
    generatedAt:
        DateTime.tryParse(report['generatedAt']?.toString() ?? '') ??
        DateTime.now(),
    platform: report['platform']?.toString() ?? Platform.operatingSystem,
    appVersion: report['appVersion']?.toString() ?? '-',
    sanitization: sanitization,
    account: report['currentAccount'],
    source: report['sourceMeta'],
  );
}

Future<void> copyDebugReport(
  BuildContext context,
  Map<String, dynamic> report,
) async {
  final sanitization = await resolveLogSanitization(context, report);
  if (sanitization == null || !context.mounted) return;
  final text = formatDebugReportAsLog(report, sanitization);
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) {
    unawaited(showHazukiPrompt(context, l10n(context).logsCopied));
  }
}

class LogsAppBarExportButton extends StatefulWidget {
  const LogsAppBarExportButton({super.key, required this.collectDebugInfo});

  final Future<Map<String, dynamic>> Function() collectDebugInfo;

  @override
  State<LogsAppBarExportButton> createState() => _LogsAppBarExportButtonState();
}

class _LogsAppBarExportButtonState extends State<LogsAppBarExportButton> {
  static const MethodChannel _mediaChannel = MethodChannel(
    'hazuki.comics/media',
  );
  bool _exporting = false;

  Future<void> _export() async {
    if (_exporting) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _exporting = true);
    try {
      final report = await widget.collectDebugInfo().timeout(
        const Duration(seconds: 10),
      );
      if (!mounted) return;
      final sanitization = await resolveLogSanitization(context, report);
      if (sanitization == null || !mounted) return;
      final content = formatDebugReportAsLog(report, sanitization);
      final path = await _saveLog(content);
      if (mounted && path != null) {
        unawaited(
          showHazukiPrompt(context, l10n(context).logsApplicationExportSuccess),
        );
      }
    } catch (error) {
      if (mounted) {
        unawaited(
          showHazukiPrompt(
            context,
            l10n(context).logsApplicationExportFailed(error),
            isError: true,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<String?> _saveLog(String content) async {
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    final fileName =
        'hazuki-${now.year}${two(now.month)}${two(now.day)}-'
        '${two(now.hour)}${two(now.minute)}${two(now.second)}.log';
    if (!Platform.isWindows) {
      return _mediaChannel.invokeMethod<String>('saveTextFile', {
        'suggestedFileName': fileName,
        'content': content,
      });
    }
    const logType = XTypeGroup(label: 'Log', extensions: <String>['log']);
    final profile = Platform.environment['USERPROFILE'];
    final location = await getSaveLocation(
      acceptedTypeGroups: const <XTypeGroup>[logType],
      initialDirectory: profile == null
          ? null
          : '$profile/Downloads'.replaceAll('\\', '/'),
      suggestedName: fileName,
    );
    if (location == null) return null;
    final file = File(location.path);
    await file.parent.create(recursive: true);
    await file.writeAsString(content, flush: true);
    return file.path;
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: const ValueKey<String>('logs-export'),
      tooltip: l10n(context).logsApplicationExportTooltip,
      onPressed: _exporting ? null : _export,
      icon: _exporting
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.save_alt_rounded),
    );
  }
}

class _SanitizationOption extends StatelessWidget {
  const _SanitizationOption({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.isWarning = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool isWarning;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isWarning
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color),
      title: Text(title),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!, style: TextStyle(color: color)),
      onTap: onTap,
    );
  }
}
