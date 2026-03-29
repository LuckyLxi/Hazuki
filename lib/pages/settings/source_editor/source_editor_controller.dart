import 'dart:async';

import 'package:flutter/material.dart';

class SourceEditorMetrics {
  const SourceEditorMetrics({
    required this.lineCount,
    required this.lineNumberText,
    required this.longestLine,
  });

  const SourceEditorMetrics.initial()
    : lineCount = 1,
      lineNumberText = '1',
      longestLine = '';

  final int lineCount;
  final String lineNumberText;
  final String longestLine;
}

class SourceCodeEditingController extends TextEditingController {
  static const Set<String> _keywords = {
    'async',
    'await',
    'break',
    'case',
    'catch',
    'class',
    'const',
    'continue',
    'default',
    'delete',
    'else',
    'export',
    'extends',
    'false',
    'finally',
    'for',
    'from',
    'function',
    'if',
    'import',
    'in',
    'instanceof',
    'let',
    'new',
    'null',
    'of',
    'return',
    'static',
    'super',
    'switch',
    'this',
    'throw',
    'true',
    'try',
    'typeof',
    'undefined',
    'var',
    'while',
    'yield',
  };

  static final RegExp _tokenPattern = RegExp(
    r"""//.*?$|/\*[\s\S]*?\*/|"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|`(?:\\.|[\s\S])*?`|\b(?:async|await|break|case|catch|class|const|continue|default|delete|else|export|extends|false|finally|for|from|function|if|import|in|instanceof|let|new|null|of|return|static|super|switch|this|throw|true|try|typeof|undefined|var|while|yield)\b|\b\d+(?:\.\d+)?\b""",
    multiLine: true,
  );
  static const int _syntaxHighlightCharLimit = 30000;
  static const Duration _metricsDebounceDuration = Duration(milliseconds: 40);

  SourceCodeEditingController() {
    addListener(_handleTextChanged);
    _recomputeMetricsNow();
  }

  final ValueNotifier<SourceEditorMetrics> metrics =
      ValueNotifier<SourceEditorMetrics>(const SourceEditorMetrics.initial());
  Timer? _metricsDebounceTimer;
  Timer? _syntaxHighlightEnableTimer;
  bool _syntaxHighlightEnabled = true;

  void _handleTextChanged() {
    _metricsDebounceTimer?.cancel();
    _metricsDebounceTimer = Timer(
      _metricsDebounceDuration,
      _recomputeMetricsNow,
    );
  }

  void setSyntaxHighlightEnabled(bool enabled) {
    if (_syntaxHighlightEnabled == enabled) {
      return;
    }
    _syntaxHighlightEnabled = enabled;
    notifyListeners();
  }

  void scheduleSyntaxHighlightEnable() {
    _syntaxHighlightEnableTimer?.cancel();
    _syntaxHighlightEnableTimer = Timer(const Duration(milliseconds: 140), () {
      setSyntaxHighlightEnabled(true);
    });
  }

  void _recomputeMetricsNow() {
    final source = text;
    var lineCount = 1;
    var currentLineStart = 0;
    var longestLineStart = 0;
    var longestLineLength = 0;

    for (var i = 0; i < source.length; i++) {
      if (source.codeUnitAt(i) != 10) {
        continue;
      }
      final lineLength = i - currentLineStart;
      if (lineLength > longestLineLength) {
        longestLineLength = lineLength;
        longestLineStart = currentLineStart;
      }
      lineCount++;
      currentLineStart = i + 1;
    }

    final trailingLineLength = source.length - currentLineStart;
    if (trailingLineLength > longestLineLength) {
      longestLineLength = trailingLineLength;
      longestLineStart = currentLineStart;
    }

    final buffer = StringBuffer();
    for (var i = 1; i <= lineCount; i++) {
      if (i > 1) {
        buffer.writeln();
      }
      buffer.write(i);
    }

    final longestLine = longestLineLength <= 0
        ? ''
        : source.substring(
            longestLineStart,
            longestLineStart + longestLineLength,
          );
    final nextMetrics = SourceEditorMetrics(
      lineCount: lineCount,
      lineNumberText: buffer.toString(),
      longestLine: longestLine,
    );
    final currentMetrics = metrics.value;
    if (currentMetrics.lineCount == nextMetrics.lineCount &&
        currentMetrics.lineNumberText == nextMetrics.lineNumberText &&
        currentMetrics.longestLine == nextMetrics.longestLine) {
      return;
    }
    metrics.value = nextMetrics;
  }

  @override
  void dispose() {
    removeListener(_handleTextChanged);
    _metricsDebounceTimer?.cancel();
    _syntaxHighlightEnableTimer?.cancel();
    metrics.dispose();
    super.dispose();
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final text = value.text;
    final baseStyle = style ?? const TextStyle();
    final composingRange = value.composing;
    final hasActiveComposingRange =
        withComposing &&
        composingRange.isValid &&
        !composingRange.isCollapsed &&
        composingRange.end <= text.length;
    if (hasActiveComposingRange ||
        !_syntaxHighlightEnabled ||
        text.length > _syntaxHighlightCharLimit) {
      return super.buildTextSpan(
        context: context,
        style: baseStyle,
        withComposing: withComposing,
      );
    }
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final stringStyle = baseStyle.copyWith(
      color: theme.brightness == Brightness.dark
          ? const Color(0xFFE6B673)
          : const Color(0xFF9A5B00),
    );
    final numberStyle = baseStyle.copyWith(
      color: theme.brightness == Brightness.dark
          ? const Color(0xFF8ED1A5)
          : const Color(0xFF1B7F46),
      fontWeight: FontWeight.w600,
    );
    final commentStyle = baseStyle.copyWith(
      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.82),
      fontStyle: FontStyle.italic,
    );
    final keywordStyle = baseStyle.copyWith(
      color: colorScheme.primary,
      fontWeight: FontWeight.w800,
    );

    final children = <InlineSpan>[];
    var start = 0;
    for (final match in _tokenPattern.allMatches(text)) {
      if (match.start > start) {
        children.add(
          TextSpan(text: text.substring(start, match.start), style: baseStyle),
        );
      }
      final token = match.group(0) ?? '';
      children.add(
        TextSpan(
          text: token,
          style: _styleForToken(
            token,
            baseStyle: baseStyle,
            keywordStyle: keywordStyle,
            stringStyle: stringStyle,
            numberStyle: numberStyle,
            commentStyle: commentStyle,
          ),
        ),
      );
      start = match.end;
    }
    if (start < text.length) {
      children.add(TextSpan(text: text.substring(start), style: baseStyle));
    }
    return TextSpan(style: baseStyle, children: children);
  }

  TextStyle _styleForToken(
    String token, {
    required TextStyle baseStyle,
    required TextStyle keywordStyle,
    required TextStyle stringStyle,
    required TextStyle numberStyle,
    required TextStyle commentStyle,
  }) {
    if (token.startsWith('//') || token.startsWith('/*')) {
      return commentStyle;
    }
    if (token.startsWith('"') ||
        token.startsWith("'") ||
        token.startsWith('`')) {
      return stringStyle;
    }
    if (_keywords.contains(token)) {
      return keywordStyle;
    }
    if (RegExp(r'^\d+(?:\.\d+)?$').hasMatch(token)) {
      return numberStyle;
    }
    return baseStyle;
  }
}
