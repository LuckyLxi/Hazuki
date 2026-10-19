import 'package:flutter/material.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/shared/appearance/appearance_settings.dart';

import 'appearance_layout_option.dart';

String favoriteLayoutLabel(AppLocalizations strings, FavoriteLayout layout) {
  return switch (layout) {
    FavoriteLayout.list => strings.displayFavoriteLayoutList,
    FavoriteLayout.grid3 => strings.displayFavoriteLayoutGrid3,
    FavoriteLayout.grid2 => strings.displayFavoriteLayoutGrid2,
    FavoriteLayout.coverOnly => strings.displayFavoriteLayoutCoverOnly,
  };
}

Future<FavoriteLayout?> showFavoriteLayoutPicker(
  BuildContext context, {
  required FavoriteLayout selected,
}) {
  final strings = AppLocalizations.of(context)!;
  return showModalBottomSheet<FavoriteLayout>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 16),
              child: Text(
                strings.displayFavoriteLayoutTitle,
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
            ),
            GridView.count(
              key: const ValueKey('favorite-layout-picker-grid'),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 2.15,
              children: [
                for (final layout in FavoriteLayout.values)
                  AppearanceLayoutOption(
                    key: ValueKey('favorite-layout-option-${layout.name}'),
                    icon: switch (layout) {
                      FavoriteLayout.list => Icons.view_agenda_outlined,
                      FavoriteLayout.grid3 => Icons.apps_rounded,
                      FavoriteLayout.grid2 => Icons.grid_view_rounded,
                      FavoriteLayout.coverOnly => Icons.view_module_outlined,
                    },
                    label: favoriteLayoutLabel(strings, layout),
                    selected: layout == selected,
                    colorScheme: Theme.of(sheetContext).colorScheme,
                    onTap: () => Navigator.of(sheetContext).pop(layout),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
