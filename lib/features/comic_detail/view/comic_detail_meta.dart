import 'dart:async';

import 'package:hazuki/services/source/plugins/source_plugin_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hazuki/models/hazuki_models.dart';

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showComicId)
          ComicDetailIdRow(
            id: details.id,
            onCopy: () => onCopyId(details.id),
            useMobileStyle: useMobileStyle,
          ),
        for (final field in details.infoFields)
          if (field.values.isNotEmpty)
            ComicDetailMetaRow(
              useMobileStyle: useMobileStyle,
              label: localizeSourcePluginText(
                field.label,
                Localizations.localeOf(context).toLanguageTag(),
              ),
              values: field.values,
              onValuePressed: switch (field.action) {
                ComicInfoAction.search => onTagValuePressed,
                ComicInfoAction.copy => onMetaValueLongPress,
                ComicInfoAction.none => null,
              },
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
  final ValueChanged<String>? onValuePressed;
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
                disabledColor: useMobileStyle
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
                onPressed: onValuePressed == null
                    ? null
                    : () => onValuePressed!(value.trim()),
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
