import '../../models/hazuki_models.dart';
import 'favorite_app_bar_actions_state.dart';

const defaultCloudFavoriteFolder = FavoriteFolder(
  id: '0',
  name: '__favorite_all__',
  source: FavoriteFolderSource.cloud,
);

class FavoritePageState {
  bool isFirstLoad = true;
  FavoritePageMode mode = FavoritePageMode.cloud;
  List<ExploreComic> comics = const <ExploreComic>[];
  List<FavoriteFolder> folders = const <FavoriteFolder>[
    defaultCloudFavoriteFolder,
  ];
  String selectedCloudFolderId = '0';
  String selectedLocalFolderId = '';
  String? errorMessage;
  bool initialLoading = true;
  bool refreshing = false;
  bool loadingMore = false;
  bool hasMore = true;
  bool loadingFolders = false;
  int currentPage = 1;
  int listRequestVersion = 0;
  String favoriteSortOrder = 'mr';

  String get selectedFolderId => mode == FavoritePageMode.local
      ? selectedLocalFolderId
      : selectedCloudFolderId;

  void setMode(FavoritePageMode value) {
    mode = value;
  }

  void setSelectedFolderId(String folderId) {
    if (mode == FavoritePageMode.local) {
      selectedLocalFolderId = folderId;
      return;
    }
    selectedCloudFolderId = folderId;
  }

  FavoriteAppBarActionsState buildAppBarActionsState({
    required bool isLogged,
    required bool supportFavoriteSortOrder,
    required bool supportFavoriteFolderAdd,
  }) {
    if (mode == FavoritePageMode.local) {
      return FavoriteAppBarActionsState(
        showSort: true,
        showCreateFolder: true,
        currentSortOrder: favoriteSortOrder,
        showModeToggle: true,
        currentMode: mode,
      );
    }

    return FavoriteAppBarActionsState(
      showSort: isLogged && supportFavoriteSortOrder,
      showCreateFolder: isLogged && supportFavoriteFolderAdd,
      currentSortOrder: favoriteSortOrder,
      showModeToggle: true,
      currentMode: mode,
    );
  }

  void resetForReload() {
    initialLoading = true;
    refreshing = false;
    loadingMore = false;
    errorMessage = null;
    comics = const <ExploreComic>[];
    currentPage = 1;
    hasMore = true;
  }

  void resetLoggedOut() {
    comics = const <ExploreComic>[];
    folders = const <FavoriteFolder>[defaultCloudFavoriteFolder];
    selectedCloudFolderId = '0';
    errorMessage = null;
    initialLoading = false;
    refreshing = false;
    loadingMore = false;
    hasMore = true;
    currentPage = 1;
    loadingFolders = false;
    favoriteSortOrder = 'mr';
  }

  void resetForModeChange() {
    comics = const <ExploreComic>[];
    folders = mode == FavoritePageMode.local
        ? const <FavoriteFolder>[]
        : const <FavoriteFolder>[defaultCloudFavoriteFolder];
    errorMessage = null;
    initialLoading = true;
    refreshing = false;
    loadingMore = false;
    loadingFolders = false;
    hasMore = true;
    currentPage = 1;
  }

  void applyFirstPageResult(FavoriteComicsResult result) {
    if (result.errorMessage == null) {
      comics = result.comics;
      errorMessage = null;
      currentPage = 1;
      if (result.maxPage != null) {
        hasMore = currentPage < result.maxPage!;
      } else {
        hasMore = result.comics.isNotEmpty;
      }
      return;
    }
    errorMessage = result.errorMessage;
  }

  void applyNextPageResult(FavoriteComicsResult result, {required int page}) {
    final incoming = result.comics;
    comics = mergeComics(comics, incoming);
    currentPage = page;
    if (result.maxPage != null) {
      hasMore = currentPage < result.maxPage!;
    } else {
      hasMore = incoming.isNotEmpty;
    }
  }

  static List<ExploreComic> mergeComics(
    List<ExploreComic> existing,
    List<ExploreComic> incoming,
  ) {
    final merged = <String, ExploreComic>{};
    for (final comic in existing) {
      if (comic.id.isNotEmpty) {
        merged[comic.id] = comic;
      }
    }
    for (final comic in incoming) {
      if (comic.id.isNotEmpty) {
        merged[comic.id] = comic;
      }
    }
    return merged.values.toList();
  }
}
