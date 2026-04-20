import 'package:flutter/material.dart';
import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/models/hazuki_models.dart';

List<String> normalizeComicMetaValues(List<String> rawValues, {String? label}) {
  final values = <String>[];
  final seen = <String>{};

  for (final raw in rawValues) {
    var text = raw.trim();
    if (text.isEmpty) {
      continue;
    }

    if (label != null && label.isNotEmpty) {
      final lower = text.toLowerCase();
      final lowerLabel = label.toLowerCase();
      if (lower.startsWith('$lowerLabel:') ||
          lower.startsWith('$lowerLabel\uFF1A')) {
        text = text.substring(label.length + 1).trim();
      }
    }

    final parts = text
        .split(RegExp('[\\n,\\uFF0C/]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty);

    for (final part in parts) {
      if (seen.add(part)) {
        values.add(part);
      }
    }
  }

  return values;
}

String extractComicViewsText(ComicDetailsData details) {
  final keys = details.tags.keys.toList();
  if (keys.isEmpty) {
    return '';
  }
  final lastKey = keys.last;
  final values = details.tags[lastKey] ?? const <String>[];
  if (values.isEmpty) {
    return '';
  }
  return normalizeComicMetaValues(values).join(' ');
}

bool isComicAuthorKey(String key) {
  final normalized = key.trim().toLowerCase();
  return normalized == 'author' ||
      normalized == 'authors' ||
      key.trim() == '\u4f5c\u8005';
}

class ComicDetailMetaSection extends StatelessWidget {
  const ComicDetailMetaSection({
    super.key,
    required this.details,
    required this.onCopyId,
    required this.onMetaValuePressed,
    required this.onMetaValueLongPress,
  });

  final ComicDetailsData details;
  final ValueChanged<String> onCopyId;
  final ValueChanged<String> onMetaValuePressed;
  final ValueChanged<String> onMetaValueLongPress;

  @override
  Widget build(BuildContext context) {
    final strings = l10n(context);
    final authorLabel = strings.comicDetailAuthor;
    final tagLabel = strings.comicDetailTags;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ComicDetailIdRow(id: details.id, onCopy: () => onCopyId(details.id)),
        ComicDetailMetaRow(
          label: authorLabel,
          values: normalizeComicMetaValues(
            details.tags.keys
                .where(isComicAuthorKey)
                .expand((key) => details.tags[key] ?? const <String>[])
                .toList(),
            label: authorLabel,
          ),
          onValuePressed: onMetaValuePressed,
          onValueLongPress: onMetaValueLongPress,
        ),
        ComicDetailMetaRow(
          label: tagLabel,
          values: normalizeComicMetaValues(
            details.tags.entries
                .where(
                  (entry) =>
                      !isComicAuthorKey(entry.key) &&
                      entry.key != details.tags.keys.lastOrNull,
                )
                .expand((entry) => entry.value)
                .toList(),
            label: tagLabel,
          ),
          onValuePressed: onMetaValuePressed,
          onValueLongPress: onMetaValueLongPress,
        ),
      ],
    );
  }
}

class ComicDetailIdRow extends StatelessWidget {
  const ComicDetailIdRow({super.key, required this.id, required this.onCopy});

  final String id;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final trimmedId = id.trim();
    if (trimmedId.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              'ID: $trimmedId',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          IconButton(
            tooltip: '\u590d\u5236 ID',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.copy_all_outlined, size: 18),
            onPressed: onCopy,
          ),
        ],
      ),
    );
  }
}

class ComicDetailMetaRow extends StatelessWidget {
  const ComicDetailMetaRow({
    super.key,
    required this.label,
    required this.values,
    required this.onValuePressed,
    required this.onValueLongPress,
  });

  final String label;
  final List<String> values;
  final ValueChanged<String> onValuePressed;
  final ValueChanged<String> onValueLongPress;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final valueStyle = theme.textTheme.bodySmall?.copyWith(
      color: cs.onSecondaryContainer,
      fontWeight: FontWeight.w500,
    );
    final chips = values
        .map(
          (value) => Tooltip(
            message: value,
            child: GestureDetector(
              onLongPress: () => onValueLongPress(value.trim()),
              child: ActionChip(
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                backgroundColor: cs.secondaryContainer,
                side: BorderSide(
                  color: cs.outlineVariant.withValues(alpha: 0.2),
                ),
                labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                padding: EdgeInsets.zero,
                label: Text(value.trim(), style: valueStyle),
                onPressed: () => onValuePressed(value.trim()),
              ),
            ),
          ),
        )
        .toList();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ', style: theme.textTheme.bodyMedium),
          Expanded(child: Wrap(spacing: 6, runSpacing: 6, children: chips)),
        ],
      ),
    );
  }
}
