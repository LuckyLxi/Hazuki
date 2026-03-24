part of '../../main.dart';

class LogsPage extends StatelessWidget {
  const LogsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = l10n(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: hazukiFrostedAppBar(
          context: context,
          title: Text(strings.advancedDebugTitle),
          actions: const [_ApplicationLogsAppBarExportButton()],
          bottom: TabBar(
            tabs: [
              Tab(
                icon: const Icon(Icons.wifi_tethering_rounded),
                text: strings.logsNetworkTitle,
              ),
              Tab(
                icon: const Icon(Icons.description_outlined),
                text: strings.logsApplicationTitle,
              ),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_NetworkLogsTab(), _ApplicationLogsTab()],
        ),
      ),
    );
  }
}

@Deprecated('Use LogsPage')
class FavoritesDebugPage extends LogsPage {
  const FavoritesDebugPage({super.key});
}

class _ApplicationLogsAppBarExportButton extends StatefulWidget {
  const _ApplicationLogsAppBarExportButton();

  @override
  State<_ApplicationLogsAppBarExportButton> createState() =>
      _ApplicationLogsAppBarExportButtonState();
}

class _ApplicationLogsAppBarExportButtonState
    extends State<_ApplicationLogsAppBarExportButton> {
  static const MethodChannel _mediaChannel = MethodChannel(
    'hazuki.comics/media',
  );

  bool _exporting = false;

  String _buildSuggestedFileName() {
    final now = DateTime.now();
    final yyyy = now.year.toString().padLeft(4, '0');
    final mm = now.month.toString().padLeft(2, '0');
    final dd = now.day.toString().padLeft(2, '0');
    final hh = now.hour.toString().padLeft(2, '0');
    final mi = now.minute.toString().padLeft(2, '0');
    final ss = now.second.toString().padLeft(2, '0');
    return 'hazuki_application_logs_$yyyy$mm${dd}_$hh$mi$ss.json';
  }

  Future<void> _exportLogs() async {
    if (_exporting) {
      return;
    }
    setState(() {
      _exporting = true;
    });
    final strings = l10n(context);
    try {
      final debugInfo = await HazukiSourceService.instance
          .collectApplicationDebugInfo()
          .timeout(const Duration(seconds: 10));
      final prettyText = const JsonEncoder.withIndent('  ').convert(debugInfo);
      final savedUri = await _mediaChannel.invokeMethod<String>('saveTextFile', {
        'suggestedFileName': _buildSuggestedFileName(),
        'content': prettyText,
      });
      if (!mounted) {
        return;
      }
      if (savedUri != null && savedUri.isNotEmpty) {
        unawaited(
          showHazukiPrompt(context, strings.logsApplicationExportSuccess),
        );
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      unawaited(
        showHazukiPrompt(
          context,
          strings.logsApplicationExportFailed(e),
        ),
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
        final visible = controller.index == 1;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: !visible
              ? const SizedBox.shrink(key: ValueKey<String>('app_logs_export_hidden'))
              : IconButton(
                  key: const ValueKey<String>('app_logs_export_visible'),
                  tooltip: strings.logsApplicationExportTooltip,
                  onPressed: _exporting ? null : _exportLogs,
                  icon: _exporting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_alt_rounded),
                ),
        );
      },
    );
  }
}

class _NetworkLogsTab extends StatefulWidget {
  const _NetworkLogsTab();

  @override
  State<_NetworkLogsTab> createState() => _NetworkLogsTabState();
}

class _NetworkLogsTabState extends State<_NetworkLogsTab>
    with AutomaticKeepAliveClientMixin<_NetworkLogsTab> {
  String _debugText = '';
  String? _errorText;
  bool _loading = true;
  bool _fullLoading = false;
  bool _importantOnly = true;
  Map<String, dynamic>? _rawDebugInfo;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    unawaited(_loadNetworkDebugInfo());
  }

  Future<void> _copyDebugText() async {
    final text = _rawDebugInfo == null
        ? _debugText
        : _buildCopyTextFromRaw(_rawDebugInfo!);
    if (text.isEmpty) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) {
      return;
    }
    unawaited(showHazukiPrompt(context, l10n(context).favoritesDebugCopied));
  }

  Future<void> _loadNetworkDebugInfo() async {
    setState(() {
      _loading = true;
      _errorText = null;
    });

    try {
      final debugInfo = await HazukiSourceService.instance
          .collectNetworkDebugInfo()
          .timeout(const Duration(seconds: 10));
      if (!mounted) {
        return;
      }
      setState(() {
        _rawDebugInfo = Map<String, dynamic>.from(debugInfo);
        _debugText = _buildDebugTextFromRaw(_rawDebugInfo!);
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

  Future<void> _loadFullDebugInfo() async {
    setState(() {
      _fullLoading = true;
    });

    try {
      final debugInfo = await HazukiSourceService.instance
          .collectFavoritesDebugInfo(forceRefresh: true)
          .timeout(const Duration(seconds: 90));
      final prettyText = const JsonEncoder.withIndent('  ').convert(debugInfo);
      if (!mounted) {
        return;
      }
      setState(() {
        _rawDebugInfo = null;
        _debugText = prettyText;
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
          _fullLoading = false;
        });
      }
    }
  }

  String _buildDebugTextFromRaw(Map<String, dynamic> source) {
    final viewData = _buildDebugMap(
      source: source,
      importantOnly: _importantOnly,
      includeFullBody: false,
    );
    return const JsonEncoder.withIndent('  ').convert(viewData);
  }

  String _buildCopyTextFromRaw(Map<String, dynamic> source) {
    final copyData = _buildDebugMap(
      source: source,
      importantOnly: _importantOnly,
      includeFullBody: true,
      compactFullBodyForUnimportant: true,
    );
    return const JsonEncoder.withIndent('  ').convert(copyData);
  }

  Map<String, dynamic> _buildDebugMap({
    required Map<String, dynamic> source,
    required bool importantOnly,
    required bool includeFullBody,
    bool compactFullBodyForUnimportant = false,
  }) {
    final copy = Map<String, dynamic>.from(source);
    final logs = (copy['recentNetworkLogs'] is List)
        ? List<Map<String, dynamic>>.from(
            (copy['recentNetworkLogs'] as List).whereType<Map>().map(
              (e) => Map<String, dynamic>.from(e),
            ),
          )
        : <Map<String, dynamic>>[];

    final targetLogs = importantOnly
        ? logs.where(_isImportantLog).toList()
        : _limitUnimportantLogs(logs);

    final normalizedLogs = targetLogs.map((log) {
      final item = Map<String, dynamic>.from(log);
      final isImportant = _isImportantLog(item);
      if (!includeFullBody && item.containsKey('responseBodyFull')) {
        item.remove('responseBodyFull');
      } else if (includeFullBody &&
          compactFullBodyForUnimportant &&
          !isImportant &&
          item.containsKey('responseBodyFull')) {
        item['responseBodyFull'] = _toCompactBody(item['responseBodyFull']);
      }
      return item;
    }).toList();

    if (importantOnly) {
      copy['filterMode'] = 'important_only';
      copy['filterReason'] = l10n(context).favoritesDebugFilterReason;
    } else {
      copy.remove('filterMode');
      copy.remove('filterReason');
    }

    copy['recentNetworkLogs'] = normalizedLogs;
    copy['networkLogStats'] = {
      ...(copy['networkLogStats'] as Map? ?? const {}),
      'visibleCount': normalizedLogs.length,
      'totalCountBeforeFilter': logs.length,
      'importantCount': logs.where(_isImportantLog).length,
      'noiseDroppedCount': logs.length - normalizedLogs.length,
    };
    return copy;
  }

  List<Map<String, dynamic>> _limitUnimportantLogs(
    List<Map<String, dynamic>> logs,
  ) {
    const maxUnimportantLogs = 12;
    final importantLogs = <Map<String, dynamic>>[];
    final unimportantLogs = <Map<String, dynamic>>[];

    for (final log in logs) {
      if (_isImportantLog(log)) {
        importantLogs.add(log);
      } else {
        unimportantLogs.add(log);
      }
    }

    if (unimportantLogs.length <= maxUnimportantLogs) {
      return [...importantLogs, ...unimportantLogs];
    }

    final recentUnimportant = unimportantLogs
        .skip(unimportantLogs.length - maxUnimportantLogs)
        .toList();
    return [...importantLogs, ...recentUnimportant];
  }

  String _toCompactBody(dynamic body) {
    if (body == null) {
      return 'null';
    }
    final text = body.toString();
    const keep = 240;
    if (text.length <= keep) {
      return text;
    }
    final omitted = text.length - keep;
    return '${text.substring(0, keep)}... [omitted $omitted chars]';
  }

  bool _isImportantLog(Map<String, dynamic> log) {
    final statusCode = log['statusCode'] is num
        ? (log['statusCode'] as num).toInt()
        : null;
    final method = (log['method'] ?? '').toString().toUpperCase();
    final source = (log['source'] ?? '').toString().toLowerCase();
    final url = (log['url'] ?? '').toString().toLowerCase();
    final error = (log['error'] ?? '').toString().toLowerCase();
    final responsePreview = (log['responseBodyPreview'] ?? '')
        .toString()
        .toLowerCase();
    final responseFull = (log['responseBodyFull'] ?? '')
        .toString()
        .toLowerCase();

    final hasError = error.isNotEmpty && error != 'null';
    if (hasError) {
      return true;
    }

    final isSlowRequest =
        log['durationMs'] is num && (log['durationMs'] as num).toInt() >= 2500;
    if (isSlowRequest) {
      return true;
    }

    if (statusCode != null && statusCode >= 400) {
      return true;
    }

    final authChainRelated =
        source.contains('login') ||
        source.contains('avatar') ||
        source.contains('source_version') ||
        method == 'LOGIN' ||
        url.contains('/login') ||
        url.contains('/user') ||
        url.contains('/favorite') ||
        url.contains('index.json') ||
        url.contains('/jm.js') ||
        url.contains('/daily') ||
        url.contains('/daily_chk') ||
        url.contains('source://avatar') ||
        url.contains('source://account.login') ||
        url.contains('signin') ||
        url.contains('auth');
    if (authChainRelated) {
      return true;
    }

    const keywords = [
      'error',
      'failed',
      'exception',
      'timeout',
      'unauthorized',
      'forbidden',
      'denied',
      'invalid',
      'login expired',
      'not legal.user',
      'auth_fail',
      'uid',
      'photo',
      '401',
      '403',
      '500',
      '502',
      '503',
      '504',
    ];

    final combined = '$error\n$responsePreview\n$responseFull';
    return keywords.any(combined.contains);
  }

  Widget _buildActionBar(BuildContext context) {
    final strings = l10n(context);
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        FilledButton.tonalIcon(
          onPressed: (_loading || _fullLoading)
              ? null
              : () {
                  setState(() {
                    _importantOnly = !_importantOnly;
                    if (_rawDebugInfo != null) {
                      _debugText = _buildDebugTextFromRaw(_rawDebugInfo!);
                    }
                  });
                },
          icon: Icon(
            _importantOnly ? Icons.filter_alt : Icons.filter_alt_outlined,
          ),
          label: Text(strings.favoritesDebugFilterImportantTooltip),
        ),
        OutlinedButton.icon(
          onPressed: (_loading || _fullLoading) ? null : _copyDebugText,
          icon: const Icon(Icons.copy_outlined),
          label: Text(strings.favoritesDebugCopyTooltip),
        ),
        OutlinedButton.icon(
          onPressed: (_loading || _fullLoading) ? null : _loadNetworkDebugInfo,
          icon: const Icon(Icons.refresh_rounded),
          label: Text(strings.favoritesDebugRefreshTooltip),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final strings = l10n(context);
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorText != null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _LogsErrorCard(
            icon: Icons.wifi_tethering_error_rounded,
            title: strings.logsNetworkTitle,
            message: strings.favoritesDebugLoadFailed(_errorText!),
            onRetry: _loadNetworkDebugInfo,
          ),
        ],
      );
    }
    return ListView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        _buildActionBar(context),
        const SizedBox(height: 12),
        FilledButton.tonalIcon(
          onPressed: _fullLoading ? null : _loadFullDebugInfo,
          icon: _fullLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.science_outlined),
          label: Text(strings.favoritesDebugFullFetchButton),
        ),
        const SizedBox(height: 12),
        _LogsTextCard(
          icon: Icons.wifi_tethering_rounded,
          title: strings.logsNetworkTitle,
          text: _debugText,
        ),
      ],
    );
  }
}

class _ApplicationLogsTab extends StatefulWidget {
  const _ApplicationLogsTab();

  @override
  State<_ApplicationLogsTab> createState() => _ApplicationLogsTabState();
}

class _ApplicationLogsTabState extends State<_ApplicationLogsTab>
    with AutomaticKeepAliveClientMixin<_ApplicationLogsTab> {
  String _debugText = '';
  String? _errorText;
  bool _loading = true;
  Map<String, dynamic>? _rawDebugInfo;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    unawaited(_loadApplicationDebugInfo());
  }

  Future<void> _copyDebugText() async {
    if (_debugText.isEmpty) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: _debugText));
    if (!mounted) {
      return;
    }
    unawaited(showHazukiPrompt(context, l10n(context).logsApplicationCopied));
  }

  Future<void> _loadApplicationDebugInfo() async {
    setState(() {
      _loading = true;
      _errorText = null;
    });

    try {
      final debugInfo = await HazukiSourceService.instance
          .collectApplicationDebugInfo()
          .timeout(const Duration(seconds: 10));
      final prettyText = const JsonEncoder.withIndent('  ').convert(debugInfo);
      if (!mounted) {
        return;
      }
      setState(() {
        _rawDebugInfo = Map<String, dynamic>.from(debugInfo);
        _debugText = prettyText;
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

  bool _hasLogs() {
    final logs = _rawDebugInfo?['recentApplicationLogs'];
    return logs is List && logs.isNotEmpty;
  }

  Widget _buildActionBar(BuildContext context) {
    final strings = l10n(context);
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        OutlinedButton.icon(
          onPressed: _loading ? null : _copyDebugText,
          icon: const Icon(Icons.copy_outlined),
          label: Text(strings.favoritesDebugCopyTooltip),
        ),
        OutlinedButton.icon(
          onPressed: _loading ? null : _loadApplicationDebugInfo,
          icon: const Icon(Icons.refresh_rounded),
          label: Text(strings.logsApplicationRefreshTooltip),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final strings = l10n(context);
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorText != null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _LogsErrorCard(
            icon: Icons.description_outlined,
            title: strings.logsApplicationTitle,
            message: strings.logsApplicationLoadFailed(_errorText!),
            onRetry: _loadApplicationDebugInfo,
          ),
        ],
      );
    }
    return ListView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        _buildActionBar(context),
        const SizedBox(height: 12),
        if (!_hasLogs()) ...[
          _LogsEmptyCard(
            icon: Icons.inbox_outlined,
            title: strings.logsApplicationTitle,
            message: strings.logsApplicationEmpty,
          ),
          const SizedBox(height: 12),
        ],
        _LogsTextCard(
          icon: Icons.description_outlined,
          title: strings.logsApplicationTitle,
          text: _debugText,
        ),
      ],
    );
  }
}

class _LogsTextCard extends StatelessWidget {
  const _LogsTextCard({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.56),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SelectableText(
            text.isEmpty ? '{}' : text,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _LogsErrorCard extends StatelessWidget {
  const _LogsErrorCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.error.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colorScheme.error),
          const SizedBox(height: 12),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: colorScheme.onErrorContainer,
            ),
          ),
          const SizedBox(height: 8),
          SelectableText(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onErrorContainer,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(l10n(context).commonRetry),
          ),
        ],
      ),
    );
  }
}

class _LogsEmptyCard extends StatelessWidget {
  const _LogsEmptyCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.56),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colorScheme.primary),
          const SizedBox(height: 12),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
