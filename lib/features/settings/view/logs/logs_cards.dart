import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:hazuki/l10n/l10n.dart';

class UnifiedLogEntryCard extends StatelessWidget {
  const UnifiedLogEntryCard({
    super.key,
    required this.log,
    required this.onOpen,
  });

  final Map<String, dynamic> log;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final level = (log['level'] ?? 'info').toString();
    final color = switch (level) {
      'error' => colors.error,
      'warning' || 'warn' => Colors.amber.shade700,
      _ => colors.primary,
    };
    final preview = _dataText(log['data']);
    final occurrences = (log['occurrences'] as num?)?.toInt() ?? 1;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _levelLabel(context, level),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _areaAndTagsLabel(context, log),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatTime(log['time']?.toString()),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              Text(
                '${log['title'] ?? 'Log'}${occurrences > 1 ? ' × $occurrences' : ''}',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (preview.isNotEmpty) ...[
                const SizedBox(height: 7),
                Text(
                  preview,
                  maxLines: 8,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontFamily: 'monospace',
                    height: 1.35,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  l10n(context).logsViewDetails,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _dataText(Object? data) {
    if (data == null) return '';
    if (data is String) return data;
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  static String _formatTime(String? value) {
    final time = DateTime.tryParse(value ?? '')?.toLocal();
    if (time == null) return value ?? '';
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(time.hour)}:${two(time.minute)}:${two(time.second)}';
  }
}

String _areaAndTagsLabel(BuildContext context, Map<String, dynamic> log) {
  final area = _areaLabel(context, (log['area'] ?? '').toString());
  final tags = log['tags'];
  if (tags is List && tags.contains('performance')) {
    return '$area · ${l10n(context).logsAreaPerformance}';
  }
  return area;
}

String logLevelLabel(BuildContext context, String level) =>
    _levelLabel(context, level);

String logAreaLabel(BuildContext context, String area) =>
    _areaLabel(context, area);

String _levelLabel(BuildContext context, String level) {
  final strings = l10n(context);
  return switch (level) {
    'error' => strings.logsLevelErrorOnly,
    'warning' || 'warn' => strings.logsLevelWarning,
    _ => strings.logsLevelInfo,
  };
}

String _areaLabel(BuildContext context, String area) {
  final strings = l10n(context);
  return switch (area) {
    'source' => strings.logsAreaSource,
    'network' => strings.logsAreaNetwork,
    'reader' => strings.logsAreaReader,
    'download' => strings.logsAreaDownload,
    'update' => strings.logsAreaUpdate,
    _ => strings.logsAreaApplication,
  };
}

class LogsErrorCard extends StatelessWidget {
  const LogsErrorCard({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            SelectableText(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(l10n(context).commonRetry),
            ),
          ],
        ),
      ),
    );
  }
}
