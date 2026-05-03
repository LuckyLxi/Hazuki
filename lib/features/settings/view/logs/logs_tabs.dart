import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/services/hazuki_source_service.dart';
import 'logs_cards.dart';

class LogsTabSpec {
  const LogsTabSpec({
    required this.type,
    required this.icon,
    required this.titleBuilder,
  });

  final String type;
  final IconData icon;
  final String Function(BuildContext context) titleBuilder;
}

const logsTabSpecs = <LogsTabSpec>[
  LogsTabSpec(
    type: debugLogTypeError,
    icon: Icons.error_outline_rounded,
    titleBuilder: _errorLogsTitle,
  ),
  LogsTabSpec(
    type: debugLogTypeAction,
    icon: Icons.touch_app_outlined,
    titleBuilder: _actionLogsTitle,
  ),
  LogsTabSpec(
    type: debugLogTypeSystem,
    icon: Icons.settings_suggest_outlined,
    titleBuilder: _systemLogsTitle,
  ),
  LogsTabSpec(
    type: debugLogTypePerformance,
    icon: Icons.speed_rounded,
    titleBuilder: _performanceLogsTitle,
  ),
];

String _errorLogsTitle(BuildContext context) => l10n(context).logsErrorTitle;
String _actionLogsTitle(BuildContext context) => l10n(context).logsActionTitle;
String _systemLogsTitle(BuildContext context) => l10n(context).logsSystemTitle;
String _performanceLogsTitle(BuildContext context) =>
    l10n(context).logsPerformanceTitle;

Future<Map<String, dynamic>> collectVisibleLogsForIndex(int index) {
  final clampedIndex = index.clamp(0, logsTabSpecs.length - 1).toInt();
  final spec = logsTabSpecs[clampedIndex];
  return HazukiSourceService.instance.collectTypedDebugInfo(spec.type);
}

String formatVisibleLogs(Map<String, dynamic> debugInfo) {
  return const JsonEncoder.withIndent('  ').convert(debugInfo);
}

class DebugLogsTab extends StatefulWidget {
  const DebugLogsTab({super.key, required this.spec});

  final LogsTabSpec spec;

  @override
  State<DebugLogsTab> createState() => _DebugLogsTabState();
}

class _DebugLogsTabState extends State<DebugLogsTab>
    with AutomaticKeepAliveClientMixin<DebugLogsTab> {
  Map<String, dynamic>? _debugInfo;
  String? _errorText;
  bool _loading = true;
  String _searchQuery = '';
  String? _selectedSource;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    unawaited(_loadLogs());
  }

  @override
  void didUpdateWidget(DebugLogsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.spec.type != widget.spec.type) {
      unawaited(_loadLogs());
    }
  }

  Future<void> _loadLogs() async {
    setState(() {
      _loading = true;
      _errorText = null;
    });
    try {
      final debugInfo = await HazukiSourceService.instance
          .collectTypedDebugInfo(widget.spec.type)
          .timeout(const Duration(seconds: 10));
      if (!mounted) {
        return;
      }
      setState(() {
        _debugInfo = debugInfo;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> _rawLogs() {
    final logs = _debugInfo?['logs'];
    if (logs is! List) {
      return const <Map<String, dynamic>>[];
    }
    return logs
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList(growable: false);
  }

  List<Map<String, dynamic>> _filteredLogs() {
    final raw = _rawLogs();
    if (_searchQuery.isEmpty && _selectedSource == null) return raw;
    return raw.where((log) {
      if (_selectedSource != null && log['source'] != _selectedSource) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final title = (log['title'] as String? ?? '').toLowerCase();
        final preview = (log['contentPreview'] as String? ?? '').toLowerCase();
        if (!title.contains(q) && !preview.contains(q)) return false;
      }
      return true;
    }).toList();
  }

  Set<String> _allSources() {
    return _rawLogs()
        .map((l) => l['source'] as String? ?? '')
        .where((s) => s.isNotEmpty)
        .toSet();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final title = widget.spec.titleBuilder(context);
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorText != null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          LogsErrorCard(
            icon: widget.spec.icon,
            title: title,
            message: l10n(context).logsLoadFailed(_errorText!),
            onRetry: _loadLogs,
          ),
        ],
      );
    }

    final rawLogs = _rawLogs();
    if (rawLogs.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          LogsEmptyCard(
            icon: widget.spec.icon,
            title: title,
            message: l10n(context).logsEmpty,
          ),
        ],
      );
    }

    final sources = _allSources();
    final logs = _filteredLogs();

    return Column(
      children: [
        _LogsSearchBar(
          query: _searchQuery,
          onChanged: (v) => setState(() {
            _searchQuery = v;
          }),
          onClear: () => setState(() {
            _searchQuery = '';
          }),
        ),
        if (sources.length > 1)
          _SourceFilterChips(
            sources: sources,
            selected: _selectedSource,
            onSelected: (s) => setState(() {
              _selectedSource = s;
            }),
          ),
        Expanded(
          child: logs.isEmpty
              ? ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    LogsEmptyCard(
                      icon: Icons.search_off_rounded,
                      title: title,
                      message: l10n(context).logsFilterNoResults,
                    ),
                  ],
                )
              : ListView.separated(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  itemBuilder: (context, index) {
                    return DebugLogEntryCard(log: logs[index]);
                  },
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemCount: logs.length,
                ),
        ),
      ],
    );
  }
}

class _LogsSearchBar extends StatefulWidget {
  const _LogsSearchBar({
    required this.query,
    required this.onChanged,
    required this.onClear,
  });

  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  State<_LogsSearchBar> createState() => _LogsSearchBarState();
}

class _LogsSearchBarState extends State<_LogsSearchBar> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.query);
  }

  @override
  void didUpdateWidget(_LogsSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.query != _controller.text) {
      _controller.text = widget.query;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: TextField(
        controller: _controller,
        onChanged: widget.onChanged,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: l10n(context).logsSearchHint,
          hintStyle: TextStyle(
            fontSize: 14,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 20,
            color: colorScheme.onSurfaceVariant,
          ),
          suffixIcon: widget.query.isNotEmpty
              ? IconButton(
                  iconSize: 18,
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () {
                    _controller.clear();
                    widget.onClear();
                  },
                )
              : null,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}

class _SourceFilterChips extends StatelessWidget {
  const _SourceFilterChips({
    required this.sources,
    required this.selected,
    required this.onSelected,
  });

  final Set<String> sources;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final allSources = ['', ...sources.toList()..sort()];
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        itemCount: allSources.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final source = allSources[index];
          final isAll = source.isEmpty;
          final isSelected = isAll ? selected == null : selected == source;
          final label = isAll ? l10n(context).logsSourceAll : source;
          return FilterChip(
            label: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected
                    ? colorScheme.onSecondaryContainer
                    : colorScheme.onSurfaceVariant,
              ),
            ),
            selected: isSelected,
            onSelected: (_) => onSelected(isAll ? null : source),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            showCheckmark: false,
            selectedColor: colorScheme.secondaryContainer,
            backgroundColor: colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.4,
            ),
            side: BorderSide.none,
          );
        },
      ),
    );
  }
}
