import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/services/source/plugins/source_sort_options.dart';
import 'package:hazuki/shared/comments/comments_sort_delegate.dart';
import 'package:hazuki/widgets/hazuki_frosted_menu.dart';
import 'package:hazuki/widgets/hazuki_frosted_menu_button.dart';

class CommentsSortBinding extends ValueNotifier<CommentsSortDelegate?> {
  CommentsSortBinding() : super(null);

  bool _disposed = false;

  void attach(CommentsSortDelegate delegate) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_disposed) value = delegate;
    });
  }

  void detach(CommentsSortDelegate delegate) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_disposed && identical(value, delegate)) value = null;
    });
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class CommentsSortScope extends InheritedWidget {
  const CommentsSortScope({
    super.key,
    required this.binding,
    required super.child,
  });

  final CommentsSortBinding binding;

  static CommentsSortBinding? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CommentsSortScope>()?.binding;

  @override
  bool updateShouldNotify(CommentsSortScope oldWidget) =>
      binding != oldWidget.binding;
}

class CommentsSortButton extends StatelessWidget {
  const CommentsSortButton({super.key, this.padding = EdgeInsets.zero});

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final binding = CommentsSortScope.maybeOf(context);
    if (binding == null) return const SizedBox.shrink();
    return ValueListenableBuilder<CommentsSortDelegate?>(
      valueListenable: binding,
      builder: (context, delegate, _) {
        if (delegate == null) return const SizedBox.shrink();
        return ListenableBuilder(
          listenable: delegate,
          builder: (context, _) {
            final options = delegate.sortOptions;
            final menuBinding = SourcePluginMenuBinding<String>(
              menuId: 'comments.sort',
              sourceKey: delegate.sourceKey.isEmpty ? null : delegate.sourceKey,
            );
            if (options.orders.isEmpty &&
                menuBinding.resolve(context).entries.isEmpty) {
              return const SizedBox.shrink();
            }
            final language = Localizations.localeOf(context).languageCode;
            final labels = options.orders.map(
              (key, label) =>
                  MapEntry(key, sourceOrderLabel(label, language, key)),
            );
            return Padding(
              padding: padding,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: HazukiFrostedMenuButton<String>(
                  pluginMenu: menuBinding,
                  tooltip: l10n(context).searchSortTooltip,
                  selected: delegate.selectedOrder,
                  options: [
                    for (final entry in labels.entries)
                      HazukiFrostedMenuOption(
                        value: entry.key,
                        label: entry.value,
                      ),
                  ],
                  onSelected: (order) => unawaited(delegate.setOrder(order)),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            labels[delegate.selectedOrder] ??
                                delegate.selectedOrder,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.swap_vert, size: 18),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
