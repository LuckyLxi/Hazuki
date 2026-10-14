import 'dart:async';

import 'package:hazuki/shared/source_presentation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    this.useMobileStyle = false,
    required this.onCopyId,
    required this.onTagValuePressed,
    required this.onMetaValueLongPress,
  });

  final ComicDetailsData details;
  final bool showComicId;
  final bool useMobileStyle;
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
    final isJm = sourceFeature(
      details.sourceKey,
      'showComicId',
      context: context,
    );
    final showUploader = sourceFeature(
      details.sourceKey,
      'showUploader',
      context: context,
    );
    final showCategories = sourceFeature(
      details.sourceKey,
      'showCategories',
      context: context,
    );
    final showChineseTeam = sourceFeature(
      details.sourceKey,
      'showChineseTeam',
      context: context,
    );
    final detailTagGroups = sourcePresentation(
      details.sourceKey,
      context: context,
    )['detailTagGroups'];
    final tagGroups = detailTagGroups is List
        ? detailTagGroups
              .whereType<String>()
              .map((group) => group.trim().toLowerCase())
              .toSet()
        : null;
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
            (entry) => tagGroups != null
                ? tagGroups.contains(entry.key.trim().toLowerCase())
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
          ComicDetailIdRow(
            id: details.id,
            onCopy: () => onCopyId(details.id),
            useMobileStyle: useMobileStyle,
          ),
        ComicDetailMetaRow(
          useMobileStyle: useMobileStyle,
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
        if (showCategories)
          ComicDetailMetaRow(
            useMobileStyle: useMobileStyle,
            label: categoryLabel,
            values: categoryValues,
            onValuePressed: onTagValuePressed,
            onValueLongPress: onMetaValueLongPress,
          ),
        ComicDetailMetaRow(
          useMobileStyle: useMobileStyle,
          label: tagLabel,
          values: tagValues,
          onValuePressed: onTagValuePressed,
          onValueLongPress: onMetaValueLongPress,
        ),
        if (isJm)
          ComicDetailMetaRow(
            useMobileStyle: useMobileStyle,
            label: jmWorkLabel,
            values: workValues,
            onValuePressed: onTagValuePressed,
            onValueLongPress: onMetaValueLongPress,
          ),
        if (isJm)
          ComicDetailMetaRow(
            useMobileStyle: useMobileStyle,
            label: jmActorLabel,
            values: actorValues,
            onValuePressed: onTagValuePressed,
            onValueLongPress: onMetaValueLongPress,
          ),
        if (showUploader)
          ComicDetailMetaRow(
            useMobileStyle: useMobileStyle,
            label: uploaderLabel,
            values: normalizeComicMetaValues([details.uploader]),
            onValuePressed: onTagValuePressed,
            onValueLongPress: onMetaValueLongPress,
          ),
        if (showChineseTeam)
          ComicDetailMetaRow(
            useMobileStyle: useMobileStyle,
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
  const ComicDetailIdRow({
    super.key,
    required this.id,
    required this.onCopy,
    this.useMobileStyle = false,
  });

  final String id;
  final VoidCallback onCopy;
  final bool useMobileStyle;

  @override
  Widget build(BuildContext context) {
    final trimmedId = id.trim();
    if (trimmedId.isEmpty) {
      return const SizedBox.shrink();
    }

    if (useMobileStyle) {
      final theme = Theme.of(context);
      final colors = theme.colorScheme;
      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onLongPress: () {
            unawaited(HapticFeedback.lightImpact());
            onCopy();
          },
          child: Chip(
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            backgroundColor: colors.primary.withValues(alpha: 0.08),
            side: BorderSide.none,
            labelPadding: const EdgeInsets.symmetric(horizontal: 4),
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(7),
            ),
            label: Text(
              'ID: $trimmedId',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      );
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
    this.useMobileStyle = false,
  });

  final String label;
  final List<String> values;
  final ValueChanged<String> onValuePressed;
  final ValueChanged<String> onValueLongPress;
  final bool useMobileStyle;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final valueStyle = theme.textTheme.bodySmall?.copyWith(
      color: useMobileStyle ? cs.onSurfaceVariant : cs.onSecondaryContainer,
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
                backgroundColor: useMobileStyle
                    ? cs.primary.withValues(alpha: 0.08)
                    : cs.secondaryContainer,
                side: useMobileStyle
                    ? BorderSide.none
                    : BorderSide(
                        color: cs.outlineVariant.withValues(alpha: 0.2),
                      ),
                labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                padding: EdgeInsets.zero,
                shape: useMobileStyle
                    ? RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(7),
                      )
                    : null,
                label: Text(
                  value.trim(),
                  style: valueStyle,
                  maxLines: useMobileStyle ? 1 : null,
                  overflow: useMobileStyle ? TextOverflow.ellipsis : null,
                ),
                onPressed: () => onValuePressed(value.trim()),
              ),
            ),
          ),
        )
        .toList();

    return Padding(
      padding: EdgeInsets.only(top: useMobileStyle ? 16 : 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (useMobileStyle)
            SizedBox(
              width: 56,
              child: Padding(
                padding: const EdgeInsets.only(top: 5, right: 8),
                child: Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            Text('$label: ', style: theme.textTheme.bodyMedium),
          Expanded(child: Wrap(spacing: 6, runSpacing: 6, children: chips)),
        ],
      ),
    );
  }
}
