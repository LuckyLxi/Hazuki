import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/favorite/favorite.dart';
import 'package:hazuki/features/favorite/state/favorite_page_state.dart';
import 'package:hazuki/models/hazuki_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FavoriteFolderSelectionResult', () {
    test('parses storage keys and exposes selection diffs', () {
      const cloudNew = FavoriteFolderHandle(
        source: FavoriteFolderSource.cloud,
        id: 'cloud-new',
      );
      const cloudOld = FavoriteFolderHandle(
        source: FavoriteFolderSource.cloud,
        id: 'cloud-old',
      );
      const localCurrent = FavoriteFolderHandle(
        source: FavoriteFolderSource.local,
        id: 'local-current',
      );

      final result = FavoriteFolderSelectionResult(
        selected: {cloudNew.storageKey, localCurrent.storageKey, 'broken'},
        initial: {cloudOld.storageKey, localCurrent.storageKey},
      );

      expect(result.addTargets, {cloudNew.storageKey, 'broken'});
      expect(result.removeTargets, {cloudOld.storageKey});
      expect(result.folderIdsForSource(FavoriteFolderSource.cloud), {
        'cloud-new',
      });
      expect(result.folderIdsForSource(FavoriteFolderSource.local), {
        'local-current',
      });
      expect(result.initialFolderIdsForSource(FavoriteFolderSource.cloud), {
        'cloud-old',
      });
      expect(result.hasChanges, isTrue);
      expect(result.hasSelection, isTrue);
    });
  });

  group('applyFavoriteFolderSelectionChanges', () {
    test('switches cloud favorite once in single-folder mode', () async {
      final repository = _RecordingFavoriteFoldersRepository();
      const details = _comicDetails;
      const oldCloud = FavoriteFolderHandle(
        source: FavoriteFolderSource.cloud,
        id: 'old-cloud',
      );
      const newCloud = FavoriteFolderHandle(
        source: FavoriteFolderSource.cloud,
        id: 'new-cloud',
      );

      final result = await applyFavoriteFolderSelectionChanges(
        repository: repository,
        details: details,
        selection: FavoriteFolderSelectionResult(
          selected: {newCloud.storageKey},
          initial: {oldCloud.storageKey},
        ),
        singleFolderOnly: true,
      );

      expect(repository.cloudToggleCalls, [
        const _ToggleCall(
          comicId: 'comic-id',
          isAdding: true,
          folderId: 'new-cloud',
        ),
      ]);
      expect(repository.localToggleCalls, isEmpty);
      expect(result.selectedCloudFolderIds, {'new-cloud'});
      expect(result.hasSelection, isTrue);
    });

    test('applies cloud and local diffs in multi-folder mode', () async {
      final repository = _RecordingFavoriteFoldersRepository();
      const details = _comicDetails;
      const oldCloud = FavoriteFolderHandle(
        source: FavoriteFolderSource.cloud,
        id: 'old-cloud',
      );
      const newCloud = FavoriteFolderHandle(
        source: FavoriteFolderSource.cloud,
        id: 'new-cloud',
      );
      const oldLocal = FavoriteFolderHandle(
        source: FavoriteFolderSource.local,
        id: 'old-local',
      );
      const newLocal = FavoriteFolderHandle(
        source: FavoriteFolderSource.local,
        id: 'new-local',
      );

      await applyFavoriteFolderSelectionChanges(
        repository: repository,
        details: details,
        selection: FavoriteFolderSelectionResult(
          selected: {newCloud.storageKey, newLocal.storageKey},
          initial: {oldCloud.storageKey, oldLocal.storageKey},
        ),
        singleFolderOnly: false,
      );

      expect(repository.cloudToggleCalls, [
        const _ToggleCall(
          comicId: 'comic-id',
          isAdding: true,
          folderId: 'new-cloud',
        ),
        const _ToggleCall(
          comicId: 'comic-id',
          isAdding: false,
          folderId: 'old-cloud',
        ),
      ]);
      expect(repository.localToggleCalls, [
        const _ToggleCall(
          comicId: 'comic-id',
          isAdding: true,
          folderId: 'new-local',
        ),
        const _ToggleCall(
          comicId: 'comic-id',
          isAdding: false,
          folderId: 'old-local',
        ),
      ]);
    });
  });

  group('FavoriteFoldersViewModel', () {
    test('passes details sourceKey to local folder operations', () async {
      final repository = _RecordingFavoriteFoldersRepository();
      final viewModel = FavoriteFoldersViewModel(
        repository: repository,
        details: _comicDetails,
        cloudFavoriteOverride: null,
        initialIsFavorite: false,
        singleFolderOnly: false,
      );
      addTearDown(viewModel.dispose);

      await viewModel.load(initialLoad: true);
      await viewModel.createFolder('New', FavoriteFolderSource.local);
      await viewModel.deleteFolder(
        const FavoriteFolder(
          id: 'local-folder',
          name: 'Local',
          source: FavoriteFolderSource.local,
        ),
      );

      expect(repository.localLoadSourceKeys, everyElement('source-a'));
      expect(repository.localAddSourceKeys, ['source-a']);
      expect(repository.localDeleteSourceKeys, ['source-a']);
    });
  });

  group('FavoritePageData', () {
    test('keeps mode-specific selected folders and reset defaults', () {
      final data = FavoritePageData()
        ..selectedCloudFolderId = 'cloud-folder'
        ..selectedLocalFolderId = 'local-folder';

      expect(data.selectedFolderId, 'cloud-folder');
      data.setMode(FavoritePageMode.local);
      expect(data.selectedFolderId, 'local-folder');

      data.resetForModeChange();

      expect(data.folders, isEmpty);
      expect(data.comics, isEmpty);
      expect(data.initialLoading, isTrue);
      expect(data.loadingMore, isFalse);
      expect(data.hasMore, isTrue);
    });

    test('merges paged comics by non-empty id', () {
      const first = ExploreComic(
        id: '1',
        title: 'First',
        subTitle: '',
        cover: '',
      );
      const updated = ExploreComic(
        id: '1',
        title: 'Updated',
        subTitle: '',
        cover: '',
      );
      const second = ExploreComic(
        id: '2',
        title: 'Second',
        subTitle: '',
        cover: '',
      );

      expect(
        FavoritePageData.mergeComics(const [first], const [updated, second]),
        const [updated, second],
      );
    });
  });
}

const _comicDetails = ComicDetailsData(
  id: 'comic-id',
  sourceKey: 'source-a',
  title: 'Title',
  subTitle: '',
  cover: '',
  description: '',
  updateTime: '',
  likesCount: '',
  chapters: {},
  tags: {},
  recommend: [],
  isFavorite: false,
  subId: '',
);

class _RecordingFavoriteFoldersRepository implements FavoriteFoldersRepository {
  @override
  bool isLogged = true;

  @override
  bool supportFavoriteFolderLoad = true;

  @override
  bool supportFavoriteFolderAdd = true;

  @override
  bool supportFavoriteFolderDelete = true;

  @override
  bool supportFavoriteToggle = true;

  @override
  bool favoriteSingleFolderForSingleComic = false;

  final cloudToggleCalls = <_ToggleCall>[];
  final localToggleCalls = <_ToggleCall>[];
  final localLoadSourceKeys = <String>[];
  final localAddSourceKeys = <String>[];
  final localDeleteSourceKeys = <String>[];

  @override
  Future<FavoriteFoldersResult> loadCloudFavoriteFolders({
    required String comicId,
  }) async {
    return const FavoriteFoldersResult.success(
      folders: <FavoriteFolder>[],
      favoritedFolderIds: <String>{},
    );
  }

  @override
  Future<void> addCloudFavoriteFolder(String name) async {}

  @override
  Future<void> deleteCloudFavoriteFolder(String id) async {}

  @override
  Future<FavoriteFoldersResult> loadLocalFavoriteFolders({
    required String comicId,
    String sourceKey = '',
  }) async {
    localLoadSourceKeys.add(sourceKey);
    return const FavoriteFoldersResult.success(
      folders: <FavoriteFolder>[
        FavoriteFolder(
          id: 'local-folder',
          name: 'Local',
          source: FavoriteFolderSource.local,
        ),
      ],
      favoritedFolderIds: <String>{},
    );
  }

  @override
  Future<void> addLocalFavoriteFolder(
    String name, {
    String sourceKey = '',
  }) async {
    localAddSourceKeys.add(sourceKey);
  }

  @override
  Future<void> deleteLocalFavoriteFolder(
    String id, {
    String sourceKey = '',
  }) async {
    localDeleteSourceKeys.add(sourceKey);
  }

  @override
  Future<void> toggleCloudFavorite({
    required String comicId,
    required bool isAdding,
    required String folderId,
  }) async {
    cloudToggleCalls.add(
      _ToggleCall(comicId: comicId, isAdding: isAdding, folderId: folderId),
    );
  }

  @override
  Future<void> toggleLocalFavorite({
    required ComicDetailsData details,
    required bool isAdding,
    required String folderId,
  }) async {
    localToggleCalls.add(
      _ToggleCall(comicId: details.id, isAdding: isAdding, folderId: folderId),
    );
  }
}

class _ToggleCall {
  const _ToggleCall({
    required this.comicId,
    required this.isAdding,
    required this.folderId,
  });

  final String comicId;
  final bool isAdding;
  final String folderId;

  @override
  bool operator ==(Object other) {
    return other is _ToggleCall &&
        other.comicId == comicId &&
        other.isAdding == isAdding &&
        other.folderId == folderId;
  }

  @override
  int get hashCode => Object.hash(comicId, isAdding, folderId);

  @override
  String toString() {
    return '_ToggleCall($comicId, $isAdding, $folderId)';
  }
}
