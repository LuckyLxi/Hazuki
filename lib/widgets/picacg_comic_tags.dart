import 'package:flutter/material.dart';

class PicacgComicTags extends StatelessWidget {
  const PicacgComicTags({
    super.key,
    required this.sourceKey,
    required this.tags,
  });

  final String sourceKey;
  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    if (sourceKey != 'picacg' || tags.isEmpty) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: tags
          .map(
            (tag) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                tag,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSecondaryContainer,
                  fontSize: 10,
                ),
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}
