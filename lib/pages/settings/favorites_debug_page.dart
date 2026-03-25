part of '../../main.dart';

class LogsPage extends StatelessWidget {
  const LogsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = l10n(context);
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: hazukiFrostedAppBar(
          context: context,
          title: Text(strings.advancedDebugTitle),
          actions: const [_LogsAppBarExportButton()],
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
              Tab(
                icon: const Icon(Icons.chrome_reader_mode_outlined),
                text: strings.logsReaderTitle,
              ),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_NetworkLogsTab(), _ApplicationLogsTab(), _ReaderLogsTab()],
        ),
      ),
    );
  }
}

@Deprecated('Use LogsPage')
class FavoritesDebugPage extends LogsPage {
  const FavoritesDebugPage({super.key});
}

class _LogsAppBarExportButton extends StatefulWidget {
  const _LogsAppBarExportButton();

  @override
  State<_LogsAppBarExportButton> createState() =>
      _LogsAppBarExportButtonState();
}

class _LogsAppBarExportButtonState extends State<_LogsAppBarExportButton> {
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
    final prettyText = _NetworkLogsFormatter(
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

class _NetworkLogsFormatter {
  const _NetworkLogsFormatter(this.context);

  final BuildContext context;

  String buildPrettyText({
    required Map<String, dynamic> source,
    required bool importantOnly,
  }) {
    final viewData = buildMap(
      source: source,
      importantOnly: importantOnly,
      includeFullBody: false,
    );
    return const JsonEncoder.withIndent('  ').convert(viewData);
  }

  String buildCopyText({
    required Map<String, dynamic> source,
    required bool importantOnly,
  }) {
    final copyData = buildMap(
      source: source,
      importantOnly: importantOnly,
      includeFullBody: true,
      compactFullBodyForUnimportant: true,
      includeHeaders: true,
    );
    return const JsonEncoder.withIndent('  ').convert(copyData);
  }

  String buildExportText({required Map<String, dynamic> source}) {
    final exportData = buildMap(
      source: source,
      importantOnly: false,
      includeFullBody: true,
      compactFullBodyForUnimportant: true,
    );
    return const JsonEncoder.withIndent('  ').convert(exportData);
  }

  Map<String, dynamic> buildMap({
    required Map<String, dynamic> source,
    required bool importantOnly,
    required bool includeFullBody,
    bool compactFullBodyForUnimportant = false,
    bool includeHeaders = false,
  }) {
    final logs = _readLogs(source);
    final importantLogs = logs.where(_isImportantLog).toList();
    final targetLogs = importantOnly ? importantLogs : _limitUnimportantLogs(logs);
    final normalizedLogs = targetLogs
        .map(
          (log) => _normalizeLog(
            log: log,
            includeFullBody: includeFullBody,
            compactFullBodyForUnimportant: compactFullBodyForUnimportant,
            includeHeaders: includeHeaders,
          ),
        )
        .toList();

    final baseStats = source['networkLogStats'] is Map
        ? Map<String, dynamic>.from(
            (source['networkLogStats'] as Map).map(
              (key, value) => MapEntry(key.toString(), value),
            ),
          )
        : <String, dynamic>{};

    final result = <String, dynamic>{
      'generatedAt': source['generatedAt'],
      'statusText': source['statusText'],
      'platform': source['platform'],
      'sourceMeta': _normalizePayload(
        source['sourceMeta'],
        compactStrings: false,
      ),
      'isLogged': source['isLogged'],
      if (_hasMeaningfulValue(source['lastLoginDebugInfo']))
        'lastLoginDebugInfo': _normalizePayload(
          source['lastLoginDebugInfo'],
          compactStrings: !includeFullBody,
        ),
      if (_hasMeaningfulValue(source['lastSourceVersionDebugInfo']))
        'lastSourceVersionDebugInfo': _normalizePayload(
          source['lastSourceVersionDebugInfo'],
          compactStrings: !includeFullBody,
        ),
      if (importantOnly) 'filterMode': 'important_only',
      if (importantOnly)
        'filterReason': l10n(context).favoritesDebugFilterReason,
      'networkLogStats': {
        ..._pruneMap(baseStats),
        'visibleCount': normalizedLogs.length,
        'totalCountBeforeFilter': logs.length,
        'importantCount': importantLogs.length,
        'noiseDroppedCount': logs.length - targetLogs.length,
      },
      'recentNetworkLogs': normalizedLogs,
    };
    return _pruneMap(result);
  }

  List<Map<String, dynamic>> _readLogs(Map<String, dynamic> source) {
    return source['recentNetworkLogs'] is List
        ? List<Map<String, dynamic>>.from(
            (source['recentNetworkLogs'] as List).whereType<Map>().map(
              (entry) => Map<String, dynamic>.from(entry),
            ),
          )
        : <Map<String, dynamic>>[];
  }

  Map<String, dynamic> _normalizeLog({
    required Map<String, dynamic> log,
    required bool includeFullBody,
    required bool compactFullBodyForUnimportant,
    required bool includeHeaders,
  }) {
    final isImportant = _isImportantLog(log);
    final mergedCount = log['mergedCount'] is num
        ? (log['mergedCount'] as num).toInt()
        : 1;
    final result = <String, dynamic>{
      'time': log['time'],
      if (mergedCount > 1) 'lastSeenAt': log['lastSeenAt'],
      if (mergedCount > 1) 'mergedCount': mergedCount,
      'source': log['source'],
      'method': log['method'],
      'statusCode': log['statusCode'],
      'durationMs': log['durationMs'],
      'url': log['url'],
      if (_hasMeaningfulValue(log['error'])) 'error': log['error'],
      if (isImportant && _hasMeaningfulValue(log['requestData']))
        'requestData': _normalizePayload(
          log['requestData'],
          compactStrings: !includeFullBody,
        ),
      if (isImportant && includeHeaders && _hasMeaningfulValue(log['requestHeaders']))
        'requestHeaders': _normalizePayload(
          log['requestHeaders'],
          compactStrings: false,
        ),
      if (isImportant && includeHeaders && _hasMeaningfulValue(log['responseHeaders']))
        'responseHeaders': _normalizePayload(
          log['responseHeaders'],
          compactStrings: false,
        ),
      if (_hasMeaningfulValue(log['responseBodyPreview']))
        'responseBodyPreview': _toCompactBody(
          log['responseBodyPreview'],
          keep: isImportant ? 320 : 160,
        ),
      if (includeFullBody && _hasMeaningfulValue(log['responseBodyFull']))
        'responseBodyFull': compactFullBodyForUnimportant && !isImportant
            ? _toCompactBody(log['responseBodyFull'], keep: 320)
            : _normalizePayload(
                log['responseBodyFull'],
                compactStrings: false,
              ),
    };
    return _pruneMap(result);
  }

  dynamic _normalizePayload(
    dynamic value, {
    required bool compactStrings,
  }) {
    if (value == null) {
      return null;
    }
    if (value is String) {
      return compactStrings ? _toCompactBody(value) : value;
    }
    if (value is Map) {
      final result = <String, dynamic>{};
      for (final entry in value.entries) {
        final normalized = _normalizePayload(
          entry.value,
          compactStrings: compactStrings,
        );
        if (_hasMeaningfulValue(normalized)) {
          result[entry.key.toString()] = normalized;
        }
      }
      return result;
    }
    if (value is Iterable) {
      final items = value
          .map(
            (item) => _normalizePayload(item, compactStrings: compactStrings),
          )
          .where(_hasMeaningfulValue)
          .toList();
      return items;
    }
    return value;
  }

  Map<String, dynamic> _pruneMap(Map<String, dynamic> source) {
    final result = <String, dynamic>{};
    for (final entry in source.entries) {
      final pruned = _pruneValue(entry.value);
      if (_hasMeaningfulValue(pruned)) {
        result[entry.key] = pruned;
      }
    }
    return result;
  }

  dynamic _pruneValue(dynamic value) {
    if (value is Map) {
      return _pruneMap(
        Map<String, dynamic>.from(
          value.map((key, nested) => MapEntry(key.toString(), nested)),
        ),
      );
    }
    if (value is Iterable) {
      final items = value
          .map(_pruneValue)
          .where(_hasMeaningfulValue)
          .toList();
      return items;
    }
    if (value is String) {
      final text = value.trim();
      if (text.isEmpty || text.toLowerCase() == 'null') {
        return null;
      }
      return value;
    }
    return value;
  }

  bool _hasMeaningfulValue(dynamic value) {
    if (value == null) {
      return false;
    }
    if (value is String) {
      final text = value.trim();
      return text.isNotEmpty && text.toLowerCase() != 'null';
    }
    if (value is Map) {
      return value.isNotEmpty;
    }
    if (value is Iterable) {
      return value.isNotEmpty;
    }
    return true;
  }

  List<Map<String, dynamic>> _limitUnimportantLogs(
    List<Map<String, dynamic>> logs,
  ) {
    const maxUnimportantLogs = 8;
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

  String _toCompactBody(dynamic body, {int keep = 240}) {
    if (body == null) {
      return 'null';
    }
    final text = body.toString();
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

  _NetworkLogsFormatter get _formatter => _NetworkLogsFormatter(context);

  String _buildDebugTextFromRaw(Map<String, dynamic> source) {
    return _formatter.buildPrettyText(
      source: source,
      importantOnly: _importantOnly,
    );
  }

  String _buildCopyTextFromRaw(Map<String, dynamic> source) {
    return _formatter.buildCopyText(
      source: source,
      importantOnly: _importantOnly,
    );
  }

  Widget _buildActionBar(BuildContext context) {
    final strings = l10n(context);
    final disabled = _loading || _fullLoading;
    final buttons = <Widget>[
      FilledButton.tonalIcon(
        onPressed: disabled
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
        onPressed: disabled ? null : _copyDebugText,
        icon: const Icon(Icons.copy_outlined),
        label: Text(strings.favoritesDebugCopyTooltip),
      ),
      OutlinedButton.icon(
        onPressed: disabled ? null : _loadNetworkDebugInfo,
        icon: const Icon(Icons.refresh_rounded),
        label: Text(strings.favoritesDebugRefreshTooltip),
      ),
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
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final useTwoColumns = constraints.maxWidth >= 320;
        final itemWidth = useTwoColumns
            ? (constraints.maxWidth - 12) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final button in buttons)
              SizedBox(width: itemWidth, child: button),
          ],
        );
      },
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

class _ReaderLogsTab extends StatefulWidget {
  const _ReaderLogsTab();

  @override
  State<_ReaderLogsTab> createState() => _ReaderLogsTabState();
}

class _ReaderLogsTabState extends State<_ReaderLogsTab>
    with AutomaticKeepAliveClientMixin<_ReaderLogsTab> {
  String _debugText = '';
  String? _errorText;
  bool _loading = true;
  Map<String, dynamic>? _rawDebugInfo;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    unawaited(_loadReaderDebugInfo());
  }

  Future<void> _copyDebugText() async {
    if (_debugText.isEmpty) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: _debugText));
    if (!mounted) {
      return;
    }
    unawaited(showHazukiPrompt(context, l10n(context).logsReaderCopied));
  }

  Future<void> _loadReaderDebugInfo() async {
    setState(() {
      _loading = true;
      _errorText = null;
    });

    try {
      final debugInfo = await HazukiSourceService.instance
          .collectReaderDebugInfo()
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
    final logs = _rawDebugInfo?['recentReaderLogs'];
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
          onPressed: _loading ? null : _loadReaderDebugInfo,
          icon: const Icon(Icons.refresh_rounded),
          label: Text(strings.logsReaderRefreshTooltip),
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
            icon: Icons.chrome_reader_mode_outlined,
            title: strings.logsReaderTitle,
            message: strings.logsReaderLoadFailed(_errorText!),
            onRetry: _loadReaderDebugInfo,
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
            title: strings.logsReaderTitle,
            message: strings.logsReaderEmpty,
          ),
          const SizedBox(height: 12),
        ],
        _LogsTextCard(
          icon: Icons.chrome_reader_mode_outlined,
          title: strings.logsReaderTitle,
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
