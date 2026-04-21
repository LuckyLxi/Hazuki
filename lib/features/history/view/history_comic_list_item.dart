import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/widgets/widgets.dart';

class HistoryComicListItem extends StatelessWidget {
  const HistoryComicListItem({
    super.key,
    required this.comic,
    required this.index,
    required this.heroTag,
    required this.selectionMode,
    required this.selected,
    required this.onTap,
    required this.onToggleSelection,
    required this.onShowMenu,
  });

  final ExploreComic comic;
  final int index;
  final String heroTag;
  final bool selectionMode;
  final bool selected;
  final Future<void> Function() onTap;
  final ValueChanged<bool?> onToggleSelection;
  final Future<void> Function(Offset globalPosition, BuildContext itemContext)
  onShowMenu;

  @override
  Widget build(BuildContext context) {
    final item = Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Builder(
        builder: (itemContext) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onLongPressStart: (details) {
            if (!selectionMode) {
              HapticFeedback.mediumImpact();
              unawaited(onShowMenu(details.globalPosition, itemContext));
            }
          },
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => unawaited(onTap()),
            child: Ink(
              padding: EdgeInsets.fromLTRB(selectionMode ? 6 : 10, 10, 10, 10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 160),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SizeTransition(
                          sizeFactor: animation,
                          axis: Axis.horizontal,
                          axisAlignment: -1.0,
                          child: child,
                        ),
                      );
                    },
                    child: selectionMode
                        ? Padding(
                            key: const ValueKey('selection_checkbox'),
                            padding: const EdgeInsets.only(right: 6),
                            child: Checkbox(
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              value: selected,
                              onChanged: onToggleSelection,
                            ),
                          )
                        : const SizedBox.shrink(key: ValueKey('no_selection')),
                  ),
                  Hero(
                    tag: heroTag,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: comic.cover.isEmpty
                          ? Container(
                              width: 72,
                              height: 102,
                              color: Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                              child: const Icon(
                                Icons.image_not_supported_outlined,
                              ),
                            )
                          : HazukiCachedImage(
                              url: comic.cover,
                              width: 72,
                              height: 102,
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          comic.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (comic.subTitle.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            comic.subTitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 350 + (index.clamp(0, 10)) * 60),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.85 + 0.15 * value,
          alignment: Alignment.bottomCenter,
          child: Transform.translate(
            offset: Offset(0, 50 * (1 - value)),
            child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
          ),
        );
      },
      child: item,
    );
  }
}
