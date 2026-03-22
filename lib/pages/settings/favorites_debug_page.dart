part of '../../main.dart';

class FavoritesDebugPage extends StatefulWidget {
  const FavoritesDebugPage({super.key});

  @override
  State<FavoritesDebugPage> createState() => _FavoritesDebugPageState();
}

class _FavoritesDebugPageState extends State<FavoritesDebugPage> {
  String _debugText = '';
  String? _errorText;
  bool _loading = true;
  bool _fullLoading = false;
  bool _importantOnly = false;
  Map<String, dynamic>? _rawDebugInfo;

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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n(context).favoritesDebugCopied)));
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
        : logs;

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
    };
    return copy;
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

    if (statusCode != null && statusCode >= 400) {
      return true;
    }

    final authChainRelated =
        source.contains('login') ||
        source.contains('avatar') ||
        method == 'LOGIN' ||
        url.contains('/login') ||
        url.contains('/user') ||
        url.contains('/favorite') ||
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

  @override
  Widget build(BuildContext context) {
    final strings = l10n(context);
    return Scaffold(
      appBar: hazukiFrostedAppBar(
        context: context,
        title: Text(strings.advancedDebugTitle),
        actions: [
          IconButton(
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
            tooltip: strings.favoritesDebugFilterImportantTooltip,
          ),
          IconButton(
            onPressed: (_loading || _fullLoading) ? null : _copyDebugText,
            icon: const Icon(Icons.copy_outlined),
            tooltip: strings.favoritesDebugCopyTooltip,
          ),
          IconButton(
            onPressed: (_loading || _fullLoading)
                ? null
                : _loadNetworkDebugInfo,
            icon: const Icon(Icons.refresh),
            tooltip: strings.favoritesDebugRefreshTooltip,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _errorText != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SelectableText(
                  strings.favoritesDebugLoadFailed(_errorText!),
                ),
              ),
            )
          : ListView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
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
                SelectableText(
                  _debugText,
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
