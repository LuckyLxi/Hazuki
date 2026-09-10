import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/favorite/state/favorite_page_controller.dart';
import 'package:hazuki/features/favorite/support/favorite_change_coordinator.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/local_favorites/local_favorites_contracts.dart';
import 'package:hazuki/services/local_favorites/local_favorites_preferences_store.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:mocktail/mocktail.dart';

class _Source extends Mock implements SourceFavoriteGateway {}

class _Local extends Mock implements LocalFavoritesRepository {}

class _Preferences extends Mock implements LocalFavoritesPreferencesStore {}

ExploreComic _comic(String id) =>
    ExploreComic(id: id, sourceKey: 'jm', title: id, subTitle: '', cover: '');

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  late _Source source;
  late _Local local;
  late _Preferences preferences;
  late StreamController<void> cloudChanges;
  late FavoritePageController controller;
  late VoidCallback sourceChanged;
  late String activeSource;

  setUp(() {
    source = _Source();
    local = _Local();
    preferences = _Preferences();
    cloudChanges = StreamController<void>.broadcast();
    activeSource = 'jm';
    when(() => source.activeSourceKey).thenAnswer((_) => activeSource);
    when(
      () => source.cloudFavoritesChangedStream,
    ).thenAnswer((_) => cloudChanges.stream);
    when(() => source.addListener(any())).thenAnswer((call) {
      sourceChanged = call.positionalArguments.single as VoidCallback;
    });
    when(() => source.favoriteSortOrders).thenReturn(['mr', 'mp']);
    when(() => source.favoriteSortOrder).thenReturn('mr');
    when(() => source.isLogged).thenReturn(true);
    when(() => source.supportFavoriteSortOrder).thenReturn(true);
    when(() => source.supportFavoriteFolderLoad).thenReturn(true);
    when(() => source.ensureInitialized()).thenAnswer((_) async {});
    when(() => source.loadFavoriteFolders()).thenAnswer(
      (_) async => FavoriteFoldersResult.success(
        favoritedFolderIds: const {},
        folders: const [
          FavoriteFolder(
            id: '0',
            name: 'all',
            source: FavoriteFolderSource.cloud,
          ),
        ],
      ),
    );
    when(
      () => source.loadFavoriteComics(
        page: any(named: 'page'),
        folderId: any(named: 'folderId'),
      ),
    ).thenAnswer(
      (_) async => FavoriteComicsResult.success([_comic('current')]),
    );
    for (final key in ['jm', 'picacg']) {
      when(
        () => preferences.loadFavoritePageMode(sourceKey: key),
      ).thenAnswer((_) async => FavoritePageMode.cloud);
      when(
        () => preferences.loadSelectedFavoriteFolderId(
          FavoritePageMode.cloud,
          sourceKey: key,
        ),
      ).thenAnswer((_) async => '0');
      when(
        () => preferences.loadSelectedFavoriteFolderId(
          FavoritePageMode.local,
          sourceKey: key,
        ),
      ).thenAnswer((_) async => 'local');
    }
    when(
      () => preferences.saveFavoritePageMode(
        FavoritePageMode.local,
        sourceKey: 'jm',
      ),
    ).thenAnswer((_) async {});
    when(() => preferences.loadSortOrder()).thenAnswer((_) async => 'mr');
    when(() => local.loadFavoriteFolders(sourceKey: 'jm')).thenAnswer(
      (_) async => FavoriteFoldersResult.success(
        favoritedFolderIds: const {},
        folders: const [
          FavoriteFolder(
            id: 'local',
            name: 'local',
            source: FavoriteFolderSource.local,
          ),
        ],
      ),
    );
    when(
      () => local.loadFavoriteComics(
        page: 1,
        folderId: 'local',
        sortOrder: 'mr',
        sourceKey: 'jm',
      ),
    ).thenAnswer((_) async => FavoriteComicsResult.success([_comic('local')]));
    controller = FavoritePageController(
      sourceService: source,
      localFavoritesRepository: local,
      localFavoritesPreferences: preferences,
    );
  });

  tearDown(() async {
    controller.dispose();
    await cloudChanges.close();
  });

  test('local folder refresh survives a concurrent sort change', () async {
    await controller.loadInitial(timeoutMessage: 'timeout');
    await controller.toggleMode(timeoutMessage: 'timeout');
    final pending = Completer<FavoriteFoldersResult>();
    when(
      () => local.loadFavoriteFolders(sourceKey: 'jm'),
    ).thenAnswer((_) => pending.future);
    when(() => preferences.saveSortOrder('mp')).thenAnswer((_) async {});
    when(
      () => local.loadFavoriteComics(
        page: 1,
        folderId: 'local',
        sortOrder: 'mp',
        sourceKey: 'jm',
      ),
    ).thenAnswer((_) async => FavoriteComicsResult.success([_comic('sorted')]));

    final reload = controller.reloadFolders();
    await controller.changeSortOrder('mp', timeoutMessage: 'timeout');
    pending.complete(
      FavoriteFoldersResult.success(
        favoritedFolderIds: const {},
        folders: const [
          FavoriteFolder(
            id: 'local',
            name: 'renamed',
            source: FavoriteFolderSource.local,
          ),
        ],
      ),
    );
    await reload;

    expect(controller.loadingFolders, isFalse);
    expect(controller.folders.single.name, 'renamed');
    expect(controller.comics.single.id, 'sorted');
  });

  test('older folder refresh cannot overwrite the latest folders', () async {
    await controller.loadInitial(timeoutMessage: 'timeout');
    final pending = Completer<FavoriteFoldersResult>();
    when(() => source.loadFavoriteFolders()).thenAnswer((_) => pending.future);
    final oldReload = controller.reloadFolders();
    when(() => source.loadFavoriteFolders()).thenAnswer(
      (_) async => FavoriteFoldersResult.success(
        favoritedFolderIds: const {},
        folders: const [
          FavoriteFolder(
            id: '0',
            name: 'new',
            source: FavoriteFolderSource.cloud,
          ),
        ],
      ),
    );
    await controller.reloadFolders();
    pending.complete(
      FavoriteFoldersResult.success(
        favoritedFolderIds: const {},
        folders: const [
          FavoriteFolder(
            id: '0',
            name: 'old',
            source: FavoriteFolderSource.cloud,
          ),
        ],
      ),
    );
    await oldReload;
    expect(controller.loadingFolders, isFalse);
    expect(controller.folders.single.name, 'new');
  });

  for (final transition in ['logout', 'mode', 'source']) {
    test('pending cloud folders are discarded after $transition', () async {
      await controller.loadInitial(timeoutMessage: 'timeout');
      final pending = Completer<FavoriteFoldersResult>();
      when(
        () => source.loadFavoriteFolders(),
      ).thenAnswer((_) => pending.future);
      final reload = controller.reloadFolders();
      if (transition == 'logout') {
        controller.resetLoggedOut();
      } else if (transition == 'mode') {
        await controller.toggleMode(timeoutMessage: 'timeout');
      } else {
        activeSource = 'picacg';
        when(() => source.loadFavoriteFolders()).thenAnswer(
          (_) async => FavoriteFoldersResult.success(
            favoritedFolderIds: const {},
            folders: const [
              FavoriteFolder(
                id: '0',
                name: 'new',
                source: FavoriteFolderSource.cloud,
              ),
            ],
          ),
        );
        sourceChanged();
        await _settle();
      }
      final expectedFolders = controller.folders;
      pending.complete(
        FavoriteFoldersResult.success(
          favoritedFolderIds: const {},
          folders: const [
            FavoriteFolder(
              id: '0',
              name: 'stale',
              source: FavoriteFolderSource.cloud,
            ),
          ],
        ),
      );
      await reload;
      expect(controller.folders, expectedFolders);
      expect(controller.loadingFolders, isFalse);
    });
  }

  test(
    'late cloud results cannot overwrite a switch to local favorites',
    () async {
      final pending = Completer<FavoriteComicsResult>();
      when(
        () => source.loadFavoriteComics(page: 1, folderId: '0'),
      ).thenAnswer((_) => pending.future);
      final initial = controller.loadInitial(timeoutMessage: 'timeout');
      await _settle();
      await controller.toggleMode(timeoutMessage: 'timeout');
      pending.complete(FavoriteComicsResult.success([_comic('old cloud')]));
      await initial;
      expect(controller.mode, FavoritePageMode.local);
      expect(controller.comics.single.id, 'local');
      expect(controller.initialLoading, isFalse);
    },
  );

  test('logout invalidates a pending first-page result', () async {
    final pending = Completer<FavoriteComicsResult>();
    when(
      () => source.loadFavoriteComics(page: 1, folderId: '0'),
    ).thenAnswer((_) => pending.future);
    final initial = controller.loadInitial(timeoutMessage: 'timeout');
    await _settle();
    controller.resetLoggedOut();
    pending.complete(FavoriteComicsResult.success([_comic('old')]));
    await initial;
    expect(controller.comics, isEmpty);
    expect(controller.initialLoading, isFalse);
  });

  test('late selection restoration cannot overwrite a newer source', () async {
    final pendingFolder = Completer<String>();
    when(
      () => preferences.loadSelectedFavoriteFolderId(
        FavoritePageMode.cloud,
        sourceKey: 'jm',
      ),
    ).thenAnswer((_) => pendingFolder.future);
    final initial = controller.loadInitial(timeoutMessage: 'timeout');
    await _settle();
    activeSource = 'picacg';
    sourceChanged();
    await _settle();
    pendingFolder.complete('old-source-folder');
    await initial;
    expect(controller.selectedFolderId, '0');
    expect(controller.comics.single.id, 'current');
    verifyNever(
      () => source.loadFavoriteComics(page: 1, folderId: 'old-source-folder'),
    );
  });

  test(
    'local changes coalesce and queued refresh stops after disposal',
    () async {
      final changes = ChangeNotifier();
      final stream = StreamController<void>.broadcast();
      final first = Completer<void>();
      final second = Completer<void>();
      var calls = 0;
      final coordinator = FavoriteChangeCoordinator(
        localChanges: changes,
        cloudChanges: stream.stream,
        shouldRefreshLocal: () => true,
        shouldRefreshCloud: () => false,
        refreshLocal: () {
          calls++;
          return calls == 1 ? first.future : second.future;
        },
        refreshCloud: () async {},
      );
      changes.notifyListeners();
      changes.notifyListeners();
      changes.notifyListeners();
      expect(calls, 1);
      first.complete();
      await _settle();
      expect(calls, 2);
      changes.notifyListeners();
      coordinator.dispose();
      second.complete();
      await _settle();
      changes.notifyListeners();
      expect(calls, 2);
      changes.dispose();
      await stream.close();
    },
  );
}
