part of '../view/comments_page.dart';

extension _CommentsContentSupportExtension on _CommentsPageState {
  Widget _buildSelectableCommentContent(
    String content,
    TextStyle? style, {
    required String expansionKey,
  }) {
    return _ExpandableCommentContent(
      key: ValueKey<String>(expansionKey),
      spans: _buildCommentContentSpans(content, style),
      plainText: _commentPreviewText(content),
      style: style,
    );
  }

  List<InlineSpan> _buildCommentContentSpans(String content, TextStyle? style) {
    if (content.isEmpty) {
      return const <InlineSpan>[];
    }

    final spans = <InlineSpan>[];
    var start = 0;
    for (final match
        in _CommentsPageState._commentInlineImagePattern.allMatches(content)) {
      if (match.start > start) {
        _appendCommentTextSpan(
          spans,
          content.substring(start, match.start),
          style,
        );
      }

      final tag = match.group(0);
      if (tag != null) {
        final source = _decodeCommentHtmlEntities(
          (_extractHtmlAttribute(tag, 'src') ?? '').trim(),
        );
        final alt = _normalizeCommentText(
          (_extractHtmlAttribute(tag, 'alt') ?? '').trim(),
        );
        if (source.isNotEmpty) {
          spans.add(
            _buildCommentImageSpan(source: source, alt: alt, style: style),
          );
        } else if (alt.isNotEmpty) {
          spans.add(TextSpan(text: alt, style: style));
        }
      }

      start = match.end;
    }

    if (start < content.length) {
      _appendCommentTextSpan(spans, content.substring(start), style);
    }

    if (spans.isEmpty) {
      final plainText = _normalizeCommentText(content);
      if (plainText.isNotEmpty) {
        spans.add(TextSpan(text: plainText, style: style));
      }
    }

    return spans;
  }

  void _appendCommentTextSpan(
    List<InlineSpan> spans,
    String rawText,
    TextStyle? style,
  ) {
    final text = _normalizeCommentText(rawText);
    if (text.isEmpty) {
      return;
    }
    spans.add(TextSpan(text: text, style: style));
  }

  InlineSpan _buildCommentImageSpan({
    required String source,
    required String alt,
    required TextStyle? style,
  }) {
    if (hazukiNoImageModeNotifier.value) {
      return TextSpan(text: alt.isEmpty ? '[琛ㄦ儏]' : alt, style: style);
    }

    final baseFontSize =
        style?.fontSize ??
        Theme.of(context).textTheme.bodyMedium?.fontSize ??
        14;
    final imageSize = (baseFontSize * 1.25).clamp(16.0, 24.0).toDouble();
    final fallbackStyle = (style ?? const TextStyle()).copyWith(
      fontSize: baseFontSize * 0.85,
      height: 1,
    );
    final fallbackText = alt.isEmpty ? '[琛ㄦ儏]' : alt;

    Widget buildFallback() {
      return SizedBox(
        width: imageSize,
        height: imageSize,
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(fallbackText, style: fallbackStyle),
          ),
        ),
      );
    }

    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1),
        child: HazukiCachedImage(
          url: source,
          width: imageSize,
          height: imageSize,
          fit: BoxFit.contain,
          loading: buildFallback(),
          error: buildFallback(),
        ),
      ),
    );
  }

  String _commentPreviewText(String content) {
    if (content.isEmpty) {
      return '';
    }

    final buffer = StringBuffer();
    var start = 0;
    for (final match
        in _CommentsPageState._commentInlineImagePattern.allMatches(content)) {
      if (match.start > start) {
        buffer.write(
          _normalizeCommentText(content.substring(start, match.start)),
        );
      }

      final tag = match.group(0);
      if (tag != null) {
        final alt = _normalizeCommentText(
          (_extractHtmlAttribute(tag, 'alt') ?? '').trim(),
        );
        if (alt.isNotEmpty) {
          buffer.write(alt);
        }
      }

      start = match.end;
    }

    if (start < content.length) {
      buffer.write(_normalizeCommentText(content.substring(start)));
    }

    return buffer
        .toString()
        .replaceAll('\n', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _normalizeCommentText(String rawText) {
    if (rawText.isEmpty) {
      return '';
    }

    var text = rawText;
    text = text.replaceAll(_CommentsPageState._commentBreakTagPattern, '\n');
    text = text.replaceAll(
      _CommentsPageState._commentBlockClosingTagPattern,
      '\n',
    );
    text = text.replaceAll(_CommentsPageState._commentHtmlTagPattern, '');
    return _decodeCommentHtmlEntities(text);
  }

  String _decodeCommentHtmlEntities(String input) {
    if (input.isEmpty) {
      return '';
    }

    return input.replaceAllMapped(
      _CommentsPageState._commentHtmlEntityPattern,
      (match) {
        final entity = match.group(1);
        if (entity == null || entity.isEmpty) {
          return match.group(0) ?? '';
        }

        if (entity.startsWith('#x') || entity.startsWith('#X')) {
          final codePoint = int.tryParse(entity.substring(2), radix: 16);
          return codePoint == null
              ? (match.group(0) ?? '')
              : String.fromCharCode(codePoint);
        }
        if (entity.startsWith('#')) {
          final codePoint = int.tryParse(entity.substring(1));
          return codePoint == null
              ? (match.group(0) ?? '')
              : String.fromCharCode(codePoint);
        }

        switch (entity.toLowerCase()) {
          case 'amp':
            return '&';
          case 'lt':
            return '<';
          case 'gt':
            return '>';
          case 'quot':
            return '"';
          case 'apos':
            return "'";
          case 'nbsp':
            return ' ';
          default:
            return match.group(0) ?? '';
        }
      },
    );
  }

  String? _extractHtmlAttribute(String tag, String name) {
    final pattern = RegExp(
      "\\b${RegExp.escape(name)}\\s*=\\s*(?:\"([^\"]*)\"|'([^']*)'|([^\\s>]+))",
      caseSensitive: false,
    );
    final match = pattern.firstMatch(tag);
    return match?.group(1) ?? match?.group(2) ?? match?.group(3);
  }
}
