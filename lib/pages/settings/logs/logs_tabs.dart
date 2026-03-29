import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/l10n.dart';
import '../../../services/hazuki_source_service.dart';
import '../../../widgets/widgets.dart';
import 'logs_cards.dart';
import 'network_logs_formatter.dart';

class NetworkLogsTab extends StatefulWidget {
  const NetworkLogsTab({super.key});

  @override
  State<NetworkLogsTab> createState() => _NetworkLogsTabState();
}

class _NetworkLogsTabState extends State<NetworkLogsTab>
    with AutomaticKeepAliveClientMixin<NetworkLogsTab> {
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

  NetworkLogsFormatter get _formatter => NetworkLogsFormatter(context);

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
          LogsErrorCard(
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
        LogsTextCard(
          icon: Icons.wifi_tethering_rounded,
          title: strings.logsNetworkTitle,
          text: _debugText,
        ),
      ],
    );
  }
}

class ApplicationLogsTab extends StatefulWidget {
  const ApplicationLogsTab({super.key});

  @override
  State<ApplicationLogsTab> createState() => _ApplicationLogsTabState();
}

class _ApplicationLogsTabState extends State<ApplicationLogsTab>
    with AutomaticKeepAliveClientMixin<ApplicationLogsTab> {
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
          LogsErrorCard(
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
          LogsEmptyCard(
            icon: Icons.inbox_outlined,
            title: strings.logsApplicationTitle,
            message: strings.logsApplicationEmpty,
          ),
          const SizedBox(height: 12),
        ],
        LogsTextCard(
          icon: Icons.description_outlined,
          title: strings.logsApplicationTitle,
          text: _debugText,
        ),
      ],
    );
  }
}

class ReaderLogsTab extends StatefulWidget {
  const ReaderLogsTab({super.key});

  @override
  State<ReaderLogsTab> createState() => _ReaderLogsTabState();
}

class _ReaderLogsTabState extends State<ReaderLogsTab>
    with AutomaticKeepAliveClientMixin<ReaderLogsTab> {
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
          LogsErrorCard(
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
          LogsEmptyCard(
            icon: Icons.inbox_outlined,
            title: strings.logsReaderTitle,
            message: strings.logsReaderEmpty,
          ),
          const SizedBox(height: 12),
        ],
        LogsTextCard(
          icon: Icons.chrome_reader_mode_outlined,
          title: strings.logsReaderTitle,
          text: _debugText,
        ),
      ],
    );
  }
}
