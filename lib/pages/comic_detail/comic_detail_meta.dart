part of '../comic_detail_page.dart';

List<String> _normalizeComicMetaValues(
  List<String> rawValues, {
  String? label,
}) {
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

String _extractComicViewsText(ComicDetailsData details) {
  final keys = details.tags.keys.toList();
  if (keys.isEmpty) {
    return '';
  }
  final lastKey = keys.last;
  final values = details.tags[lastKey] ?? const <String>[];
  if (values.isEmpty) {
    return '';
  }
  return _normalizeComicMetaValues(values).join(' ');
}

bool _isComicAuthorKey(String key) {
  final normalized = key.trim().toLowerCase();
  return normalized == 'author' ||
      normalized == 'authors' ||
      key.trim() == '\u4f5c\u8005';
}

class _ComicDetailIdRow extends StatelessWidget {
  const _ComicDetailIdRow({required this.id, required this.onCopy});

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

class _ComicDetailMetaRow extends StatelessWidget {
  const _ComicDetailMetaRow({
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
