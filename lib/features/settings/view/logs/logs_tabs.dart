import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/services/logging/app_log_sanitizer.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/widgets/widgets.dart';

import 'logs_cards.dart';
import 'logs_export_button.dart';

class UnifiedLogsView extends StatefulWidget {
  const UnifiedLogsView({super.key, required this.debugGateway});

  final SourceDebugGateway debugGateway;

  @override
  State<UnifiedLogsView> createState() => _UnifiedLogsViewState();
}

class _UnifiedLogsViewState extends State<UnifiedLogsView> {
  Map<String, dynamic>? _report;
  Object? _error;
  bool _loading = true;
  String _query = '';
  String _level = 'all';
  String? _area;
  Timer? _reloadTimer;

  @override
  void initState() {
    super.initState();
    widget.debugGateway.logChanges.addListener(_scheduleReload);
    unawaited(_load());
  }

  @override
  void didUpdateWidget(UnifiedLogsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.debugGateway != widget.debugGateway) {
      oldWidget.debugGateway.logChanges.removeListener(_scheduleReload);
      widget.debugGateway.logChanges.addListener(_scheduleReload);
      unawaited(_load());
    }
  }

  @override
  void dispose() {
    _reloadTimer?.cancel();
    widget.debugGateway.logChanges.removeListener(_scheduleReload);
    super.dispose();
  }

  void _scheduleReload() {
    _reloadTimer?.cancel();
    _reloadTimer = Timer(const Duration(milliseconds: 120), () {
      if (mounted) unawaited(_load(showProgress: false));
    });
  }

  Future<void> _load({bool showProgress = true}) async {
    if (showProgress && mounted) setState(() => _loading = true);
    try {
      final report = await widget.debugGateway.collectAllDebugInfo();
      if (!mounted) return;
      setState(() {
        _report = report;
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted && showProgress) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _logs {
    final raw = _report?['logs'];
    if (raw is! List) return const <Map<String, dynamic>>[];
    return raw
        .whereType<Map>()
        .map((log) => Map<String, dynamic>.from(log))
        .toList(growable: false)
      ..sort(
        (a, b) => (b['time'] ?? '').toString().compareTo(
          (a['time'] ?? '').toString(),
        ),
      );
  }

  List<Map<String, dynamic>> get _filteredLogs {
    final normalizedQuery = _query.trim().toLowerCase();
    return _logs
        .where((log) {
          if (_level != 'all' && log['level'] != _level) return false;
          if (_area != null && log['area'] != _area) return false;
          if (normalizedQuery.isEmpty) return true;
          return jsonEncode(log).toLowerCase().contains(normalizedQuery);
        })
        .toList(growable: false);
  }

  Set<String> get _areas => _logs
      .map((log) => log['area']?.toString() ?? '')
      .where((area) => area.isNotEmpty)
      .toSet();

  void _openLog(Map<String, dynamic> log) {
    FocusManager.instance.primaryFocus?.unfocus();
    unawaited(
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => LogDetailPage(log: log))),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _report == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _report == null) {
      return LogsErrorCard(
        message: l10n(context).logsLoadFailed(_error!),
        onRetry: _load,
      );
    }
    final logs = _filteredLogs;
    return Column(
      children: [
        _LogFilters(
          query: _query,
          level: _level,
          area: _area,
          areas: _areas,
          onQueryChanged: (value) => setState(() => _query = value),
          onLevelChanged: (value) => setState(() => _level = value),
          onAreaChanged: (value) => setState(() => _area = value),
        ),
        Expanded(
          child: logs.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _logs.isEmpty
                          ? l10n(context).logsEmpty
                          : l10n(context).logsFilterNoResults,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    itemCount: logs.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final log = logs[index];
                      return UnifiedLogEntryCard(
                        key: ValueKey(log['id']),
                        log: log,
                        onOpen: () => _openLog(log),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

class _LogFilters extends StatelessWidget {
  const _LogFilters({
    required this.query,
    required this.level,
    required this.area,
    required this.areas,
    required this.onQueryChanged,
    required this.onLevelChanged,
    required this.onAreaChanged,
  });

  final String query;
  final String level;
  final String? area;
  final Set<String> areas;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onLevelChanged;
  final ValueChanged<String?> onAreaChanged;

  @override
  Widget build(BuildContext context) {
    final strings = l10n(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        children: [
          TextFormField(
            initialValue: query,
            onChanged: onQueryChanged,
            decoration: InputDecoration(
              hintText: strings.logsSearchHint,
              prefixIcon: const Icon(Icons.search_rounded),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _LevelChip(
                        value: 'all',
                        label: strings.logsLevelAll,
                        selected: level,
                        onChanged: onLevelChanged,
                      ),
                      const SizedBox(width: 6),
                      _LevelChip(
                        value: 'warning',
                        label: strings.logsLevelWarning,
                        selected: level,
                        onChanged: onLevelChanged,
                      ),
                      const SizedBox(width: 6),
                      _LevelChip(
                        value: 'error',
                        label: strings.logsLevelErrorOnly,
                        selected: level,
                        onChanged: onLevelChanged,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  value: area,
                  hint: Text(strings.logsAreaAll),
                  items: [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text(strings.logsAreaAll),
                    ),
                    for (final value in areas.toList()..sort())
                      DropdownMenuItem<String?>(
                        value: value,
                        child: Text(logAreaLabel(context, value)),
                      ),
                  ],
                  onChanged: onAreaChanged,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LevelChip extends StatelessWidget {
  const _LevelChip({
    required this.value,
    required this.label,
    required this.selected,
    required this.onChanged,
  });

  final String value;
  final String label;
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected == value,
      onSelected: (_) => onChanged(value),
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
    );
  }
}

class LogDetailPage extends StatelessWidget {
  const LogDetailPage({super.key, required this.log});

  final Map<String, dynamic> log;

  Future<void> _copy(BuildContext context) async {
    final mode = await resolveLogSanitization(context, log);
    if (mode == null || !context.mounted) return;
    final sanitized = const AppLogSanitizer().sanitize(log, mode);
    final text = const JsonEncoder.withIndent('  ').convert(sanitized);
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      unawaited(showHazukiPrompt(context, l10n(context).logsCopied));
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = log['data'];
    final content = data == null
        ? ''
        : data is String
        ? data
        : const JsonEncoder.withIndent('  ').convert(data);
    return Scaffold(
      appBar: hazukiFrostedAppBar(
        context: context,
        title: Text(l10n(context).logsDetailTitle),
        actions: [
          IconButton(
            tooltip: l10n(context).logsCopyField,
            onPressed: () => unawaited(_copy(context)),
            icon: const Icon(Icons.copy_outlined),
          ),
        ],
      ),
      body: SelectionArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              (log['title'] ?? 'Log').toString(),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            _DetailRow(label: 'Time', value: '${log['time'] ?? '-'}'),
            _DetailRow(
              label: 'Level',
              value: logLevelLabel(context, '${log['level'] ?? 'info'}'),
            ),
            _DetailRow(
              label: 'Area',
              value: logAreaLabel(context, '${log['area'] ?? ''}'),
            ),
            _DetailRow(label: 'Source', value: '${log['source'] ?? '-'}'),
            _DetailRow(label: 'Event', value: '${log['event'] ?? '-'}'),
            if (log['tags'] case final List tags when tags.isNotEmpty)
              _DetailRow(label: 'Tags', value: tags.join(', ')),
            if ((log['occurrences'] as num?)?.toInt() case final count?
                when count > 1) ...[
              _DetailRow(label: 'Occurrences', value: '$count'),
              _DetailRow(
                label: 'Last seen',
                value: '${log['lastSeenAt'] ?? '-'}',
              ),
            ],
            if (content.isNotEmpty) ...[
              const Divider(height: 32),
              Text(
                content,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
