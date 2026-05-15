import 'package:flutter/foundation.dart';
import 'package:hazuki/models/hazuki_models.dart';

class FavoriteAppBarActionsState {
  const FavoriteAppBarActionsState({
    required this.showSort,
    required this.showCreateFolder,
    required this.currentSortOrder,
    this.sortOrders = const <String>['mr', 'mp'],
    required this.showModeToggle,
    required this.currentMode,
  });

  final bool showSort;
  final bool showCreateFolder;
  final String currentSortOrder;
  final List<String> sortOrders;
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
        other.showModeToggle == showModeToggle &&
        other.currentMode == currentMode;
  }

  @override
  int get hashCode => Object.hash(
    showSort,
    showCreateFolder,
    currentSortOrder,
    Object.hashAll(sortOrders),
    showModeToggle,
    currentMode,
  );
}
