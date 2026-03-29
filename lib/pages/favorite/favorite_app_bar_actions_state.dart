class FavoriteAppBarActionsState {
  const FavoriteAppBarActionsState({
    required this.showSort,
    required this.showCreateFolder,
    required this.currentSortOrder,
  });

  final bool showSort;
  final bool showCreateFolder;
  final String currentSortOrder;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is FavoriteAppBarActionsState &&
        other.showSort == showSort &&
        other.showCreateFolder == showCreateFolder &&
        other.currentSortOrder == currentSortOrder;
  }

  @override
  int get hashCode => Object.hash(showSort, showCreateFolder, currentSortOrder);
}
