import '../../models/hazuki_models.dart';

class FavoriteAppBarActionsState {
  const FavoriteAppBarActionsState({
    required this.showSort,
    required this.showCreateFolder,
    required this.currentSortOrder,
    required this.showModeToggle,
    required this.currentMode,
  });

  final bool showSort;
  final bool showCreateFolder;
  final String currentSortOrder;
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
        other.showModeToggle == showModeToggle &&
        other.currentMode == currentMode;
  }

  @override
  int get hashCode => Object.hash(
    showSort,
    showCreateFolder,
    currentSortOrder,
    showModeToggle,
    currentMode,
  );
}
