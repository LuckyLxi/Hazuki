import 'package:flutter/material.dart';
import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/source/source_capabilities.dart';

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

bool isComicCategoryKey(String key) {
  final normalized = key.trim().toLowerCase();
  return normalized == 'category' ||
      normalized == 'categories' ||
      key.trim() == '\u5206\u7c7b';
}

bool isComicTagKey(String key) {
  final normalized = key.trim().toLowerCase();
  return normalized == 'tag' ||
      normalized == 'tags' ||
      key.trim() == '\u6807\u7b7e';
}

bool isComicWorkKey(String key) {
  final normalized = key.trim().toLowerCase();
  return normalized == 'work' ||
      normalized == 'works' ||
      key.trim() == '\u4f5c\u54c1';
}

bool isComicActorKey(String key) {
  final normalized = key.trim().toLowerCase();
  return normalized == 'actor' ||
      normalized == 'actors' ||
      key.trim() == '\u89d2\u8272';
}

bool isComicChineseTeamKey(String key) {
  final normalized = key.trim().toLowerCase();
  return normalized == 'chinese team' ||
      normalized == 'chineseteam' ||
      normalized == 'scanlation' ||
      normalized == 'translator' ||
      key.trim() == '\u6c49\u5316\u7ec4';
}

class ComicDetailMetaSection extends StatelessWidget {
  const ComicDetailMetaSection({
    super.key,
    required this.details,
    this.showComicId = true,
    required this.onCopyId,
    required this.onTagValuePressed,
    required this.onMetaValueLongPress,
  });

  final ComicDetailsData details;
  final bool showComicId;
  final ValueChanged<String> onCopyId;
  final ValueChanged<String> onTagValuePressed;
  final ValueChanged<String> onMetaValueLongPress;

  @override
  Widget build(BuildContext context) {
    final strings = l10n(context);
    final authorLabel = strings.comicDetailAuthor;
    final categoryLabel = strings.comicDetailCategories;
    final tagLabel = strings.comicDetailTags;
    final uploaderLabel = strings.comicDetailUploader;
    final chineseTeamLabel = strings.comicDetailChineseTeam;
    const jmWorkLabel = '\u4f5c\u54c1';
    const jmActorLabel = '\u89d2\u8272';
    final isJm = isHazukiJmSourceKey(details.sourceKey);
    final isPicacg = isHazukiPicacgSourceKey(details.sourceKey);
    final categoryValues = normalizeComicMetaValues(
      details.tags.entries
          .where((entry) => isComicCategoryKey(entry.key))
          .expand((entry) => entry.value)
          .toList(),
      label: categoryLabel,
    );
    final tagValues = normalizeComicMetaValues(
      details.tags.entries
          .where(
            (entry) => isPicacg
                ? isComicTagKey(entry.key)
                : !isComicAuthorKey(entry.key) &&
                      !(isJm && isComicWorkKey(entry.key)) &&
                      !(isJm && isComicActorKey(entry.key)) &&
                      entry.key != details.tags.keys.lastOrNull,
          )
          .expand((entry) => entry.value)
          .toList(),
      label: tagLabel,
    );
    final workValues = normalizeComicMetaValues(
      details.tags.entries
          .where((entry) => isComicWorkKey(entry.key))
          .expand((entry) => entry.value)
          .toList(),
      label: jmWorkLabel,
    );
    final actorValues = normalizeComicMetaValues(
      details.tags.entries
          .where((entry) => isComicActorKey(entry.key))
          .expand((entry) => entry.value)
          .toList(),
      label: jmActorLabel,
    );
    final chineseTeamValues = normalizeComicMetaValues(
      details.tags.entries
          .where((entry) => isComicChineseTeamKey(entry.key))
          .expand((entry) => entry.value)
          .toList(),
      label: chineseTeamLabel,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showComicId)
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
          onValuePressed: onTagValuePressed,
          onValueLongPress: onMetaValueLongPress,
        ),
        if (isPicacg)
          ComicDetailMetaRow(
            label: categoryLabel,
            values: categoryValues,
            onValuePressed: onTagValuePressed,
            onValueLongPress: onMetaValueLongPress,
          ),
        ComicDetailMetaRow(
          label: tagLabel,
          values: tagValues,
          onValuePressed: onTagValuePressed,
          onValueLongPress: onMetaValueLongPress,
        ),
        if (isJm)
          ComicDetailMetaRow(
            label: jmWorkLabel,
            values: workValues,
            onValuePressed: onTagValuePressed,
            onValueLongPress: onMetaValueLongPress,
          ),
        if (isJm)
          ComicDetailMetaRow(
            label: jmActorLabel,
            values: actorValues,
            onValuePressed: onTagValuePressed,
            onValueLongPress: onMetaValueLongPress,
          ),
        if (isPicacg)
          ComicDetailMetaRow(
            label: uploaderLabel,
            values: normalizeComicMetaValues([details.uploader]),
            onValuePressed: onTagValuePressed,
            onValueLongPress: onMetaValueLongPress,
          ),
        if (isPicacg)
          ComicDetailMetaRow(
            label: chineseTeamLabel,
            values: chineseTeamValues,
            onValuePressed: onTagValuePressed,
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
