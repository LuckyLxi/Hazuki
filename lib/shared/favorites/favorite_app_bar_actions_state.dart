import 'package:flutter/foundation.dart';

import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/source/plugins/source_favorite_menu.dart';

class FavoriteAppBarActionsState {
  const FavoriteAppBarActionsState({
    required this.showSort,
    required this.showCreateFolder,
    required this.currentSortOrder,
    this.sortOrders = const [],
    this.sortLabels = const {},
    this.menu = const [],
    this.sourceKey = '',
    required this.showModeToggle,
    required this.currentMode,
  });

  final bool showSort;
  final bool showCreateFolder;
  final String currentSortOrder;
  final List<String> sortOrders;
  final Map<String, dynamic> sortLabels;
  final List<SourceFavoriteMenuEntry> menu;
  final String sourceKey;
  final bool showModeToggle;
  final FavoritePageMode currentMode;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is FavoriteAppBarActionsState &&
        other.showSort == showSort &&
        other.showCreateFolder == showCreateFolder &&
        other.currentSortOrder == currentSortOrder &&
        listEquals(other.sortOrders, sortOrders) &&
        mapEquals(other.sortLabels, sortLabels) &&
        listEquals(other.menu, menu) &&
        other.sourceKey == sourceKey &&
        other.showModeToggle == showModeToggle &&
        other.currentMode == currentMode;
  }

  @override
  int get hashCode => Object.hash(
    showSort,
    showCreateFolder,
    currentSortOrder,
    Object.hashAll(sortOrders),
    Object.hashAllUnordered(
      sortLabels.entries.map((entry) => Object.hash(entry.key, entry.value)),
    ),
    Object.hashAll(menu),
    sourceKey,
    showModeToggle,
    currentMode,
  );
}
