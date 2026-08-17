import 'package:flutter/material.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/shared/ui_flags.dart';
import 'package:hazuki/widgets/widgets.dart';
import 'package:intl/intl.dart';

final RegExp _commentInlineImagePattern = RegExp(
  r'<img\b[^>]*>',
  caseSensitive: false,
);
final RegExp _commentBreakTagPattern = RegExp(
  r'<br\s*/?>',
  caseSensitive: false,
);
final RegExp _commentBlockClosingTagPattern = RegExp(
  r'</(?:p|div|li)\s*>',
  caseSensitive: false,
);
final RegExp _commentHtmlTagPattern = RegExp(r'<[^>]+>');
final RegExp _commentHtmlEntityPattern = RegExp(
  r'&(#x?[0-9A-Fa-f]+|[A-Za-z]+);',
);

List<InlineSpan> buildCommentContentSpans(
  BuildContext context,
  String content,
  TextStyle? style,
) {
  if (content.isEmpty) {
    return const <InlineSpan>[];
  }

  final spans = <InlineSpan>[];
  var start = 0;
  for (final match in _commentInlineImagePattern.allMatches(content)) {
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
      final alt = normalizeCommentText(
        (_extractHtmlAttribute(tag, 'alt') ?? '').trim(),
      );
      if (source.isNotEmpty) {
        spans.add(
          _buildCommentImageSpan(
            context: context,
            source: source,
            alt: alt,
            style: style,
          ),
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
    final plainText = normalizeCommentText(content);
    if (plainText.isNotEmpty) {
      spans.add(TextSpan(text: plainText, style: style));
    }
  }

  return spans;
}

String commentPreviewText(String content) {
  if (content.isEmpty) {
    return '';
  }

  final buffer = StringBuffer();
  var start = 0;
  for (final match in _commentInlineImagePattern.allMatches(content)) {
    if (match.start > start) {
      buffer.write(normalizeCommentText(content.substring(start, match.start)));
    }

    final tag = match.group(0);
    if (tag != null) {
      final alt = normalizeCommentText(
        (_extractHtmlAttribute(tag, 'alt') ?? '').trim(),
      );
      if (alt.isNotEmpty) {
        buffer.write(alt);
      }
    }

    start = match.end;
  }

  if (start < content.length) {
    buffer.write(normalizeCommentText(content.substring(start)));
  }

  return buffer
      .toString()
      .replaceAll('\n', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String commentFilterText(String content) => commentPreviewText(content);

/// Formats machine-readable source timestamps for display while leaving
/// source-specific, non-parseable timestamps untouched.
String formatCommentTime(String rawTime) {
  final timestamp = DateTime.tryParse(rawTime);
  if (timestamp == null) {
    return rawTime;
  }
  return DateFormat('yyyy-MM-dd HH:mm').format(timestamp.toLocal());
}

final RegExp _commentReplyAttributionPattern = RegExp(
  r'^\s*(.*?)\s*👉\s*(.*?)\s*$',
);

/// Separates the legacy reply attribution emitted by some sources.
({String author, String? replyTo}) parseCommentUserAttribution(
  String rawUserName,
) {
  final match = _commentReplyAttributionPattern.firstMatch(rawUserName);
  final author = match?.group(1)?.trim();
  final replyTo = match?.group(2)?.trim();
  if (author == null || author.isEmpty || replyTo == null || replyTo.isEmpty) {
    return (author: rawUserName, replyTo: null);
  }
  return (author: author, replyTo: replyTo);
}

/// Orders replies from oldest to newest. Replies without a parseable timestamp
/// are retained after dated replies in their source order.
List<ComicCommentData> sortRepliesChronologically(
  List<ComicCommentData> replies,
) {
  final indexed = replies.indexed.toList()
    ..sort((left, right) {
      final leftTime = DateTime.tryParse(left.$2.time);
      final rightTime = DateTime.tryParse(right.$2.time);
      if (leftTime == null || rightTime == null) {
        if (leftTime != null) return -1;
        if (rightTime != null) return 1;
        return left.$1.compareTo(right.$1);
      }
      final comparison = leftTime.compareTo(rightTime);
      return comparison != 0 ? comparison : left.$1.compareTo(right.$1);
    });
  return indexed.map((entry) => entry.$2).toList();
}

String normalizeCommentText(String rawText) {
  if (rawText.isEmpty) {
    return '';
  }

  var text = rawText;
  text = text.replaceAll(_commentBreakTagPattern, '\n');
  text = text.replaceAll(_commentBlockClosingTagPattern, '\n');
  text = text.replaceAll(_commentHtmlTagPattern, '');
  return _decodeCommentHtmlEntities(text);
}

void _appendCommentTextSpan(
  List<InlineSpan> spans,
  String rawText,
  TextStyle? style,
) {
  final text = normalizeCommentText(rawText);
  if (text.isEmpty) {
    return;
  }
  spans.add(TextSpan(text: text, style: style));
}

InlineSpan _buildCommentImageSpan({
  required BuildContext context,
  required String source,
  required String alt,
  required TextStyle? style,
}) {
  if (hazukiNoImageModeNotifier.value) {
    return TextSpan(text: alt.isEmpty ? '[鐞涖劍鍎廬' : alt, style: style);
  }

  final baseFontSize =
      style?.fontSize ?? Theme.of(context).textTheme.bodyMedium?.fontSize ?? 14;
  final imageSize = (baseFontSize * 1.25).clamp(16.0, 24.0).toDouble();
  final fallbackStyle = (style ?? const TextStyle()).copyWith(
    fontSize: baseFontSize * 0.85,
    height: 1,
  );
  final fallbackText = alt.isEmpty ? '[鐞涖劍鍎廬' : alt;

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

String _decodeCommentHtmlEntities(String input) {
  if (input.isEmpty) {
    return '';
  }

  return input.replaceAllMapped(_commentHtmlEntityPattern, (match) {
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
  });
}

String? _extractHtmlAttribute(String tag, String name) {
  final pattern = RegExp(
    "\\b${RegExp.escape(name)}\\s*=\\s*(?:\"([^\"]*)\"|'([^']*)'|([^\\s>]+))",
    caseSensitive: false,
  );
  final match = pattern.firstMatch(tag);
  return match?.group(1) ?? match?.group(2) ?? match?.group(3);
}
