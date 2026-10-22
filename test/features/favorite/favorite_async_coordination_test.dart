import '../../support/fake_source_task_control.dart';
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
  Object? favoriteMenu;

  setUp(() {
    source = _Source();
    local = _Local();
    preferences = _Preferences();
    cloudChanges = StreamController<void>.broadcast();
    activeSource = 'jm';
    favoriteMenu = null;
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
    when(
      () => source.loadFavoriteFolders(taskOrigin: any(named: 'taskOrigin')),
    ).thenAnswer(
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
        taskOrigin: any(named: 'taskOrigin'),
      ),
    ).thenAnswer(
      (_) async => FavoriteComicsResult.success([_comic('current')]),
    );
    for (final key in ['jm', 'picacg', '']) {
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
    when(() => preferences.saveSortOrder(any())).thenAnswer((_) async {});
    when(
      () => local.loadFavoriteFolders(sourceKey: any(named: 'sourceKey')),
    ).thenAnswer(
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
        sortOrder: 'savedNewest',
        sourceKey: any(named: 'sourceKey'),
      ),
    ).thenAnswer((_) async => FavoriteComicsResult.success([_comic('local')]));
    controller = FavoritePageController(
      presentationFor: (key) => {
        'refreshCloudFavorites': true,
        'favoriteDefaultOrder': 'mr',
        'favoriteMenu': favoriteMenu,
        'localFavoriteOrders': {'mr': 'savedNewest', 'mp': 'updatedNewest'},
      },
      sourceService: source,
      localFavoritesRepository: local,
      localFavoritesPreferences: preferences,
      taskControl: FakeSourceTaskControl(),
    );
  });

  tearDown(() async {
    controller.dispose();
    await cloudChanges.close();
  });

  test(
    'app bar state follows menu declaration changes and source identity',
    () {
      when(() => source.supportFavoriteFolderAdd).thenReturn(false);
      favoriteMenu = [
        {
          'id': 'saved',
          'title': 'Saved',
          'children': [
            {'order': 'mr'},
            {'order': 'mp'},
          ],
        },
      ];
      final first = controller.appBarActionsState;
      expect(first.sourceKey, 'jm');
      expect(first.menu.single.children.map((e) => e.order), ['mr', 'mp']);
      expect(controller.appBarActionsState, first);
      expect(controller.appBarActionsState.hashCode, first.hashCode);
      favoriteMenu = [
        {'action': 'export', 'title': 'Export'},
      ];
      expect(controller.appBarActionsState, isNot(first));
      expect(controller.appBarActionsState.menu.single.action, 'export');
      activeSource = 'picacg';
      expect(controller.appBarActionsState.sourceKey, 'picacg');
      favoriteMenu = [];
      expect(controller.appBarActionsState.menu, isEmpty);
    },
  );

  test(
    'cloud favorites require a source before login or initialization',
    () async {
      activeSource = '';
      when(() => source.isLogged).thenReturn(false);

      await controller.loadInitial(timeoutMessage: 'timeout');

      expect(controller.showSourceRequired, isTrue);
      expect(controller.showLoginRequired, isFalse);
      expect(controller.initialLoading, isFalse);
      expect(controller.errorMessage, isNull);
      verifyNever(() => source.ensureInitialized());

      activeSource = 'jm';
      expect(controller.showSourceRequired, isFalse);
      expect(controller.showLoginRequired, isTrue);
    },
  );

  test(
    'saved local favorites still load without an installed source',
    () async {
      activeSource = '';
      when(() => source.isLogged).thenReturn(false);
      when(
        () => preferences.loadFavoritePageMode(sourceKey: ''),
      ).thenAnswer((_) async => FavoritePageMode.local);

      await controller.loadInitial(timeoutMessage: 'timeout');

      expect(controller.mode, FavoritePageMode.local);
      expect(controller.showSourceRequired, isFalse);
      expect(controller.showLoginRequired, isFalse);
      expect(controller.comics.single.id, 'local');
      verifyNever(() => source.ensureInitialized());
    },
  );

  test(
    'initial load replaces the saved all ID with the plugin shelf ID',
    () async {
      when(
        () => source.loadFavoriteFolders(taskOrigin: any(named: 'taskOrigin')),
      ).thenAnswer(
        (_) async => const FavoriteFoldersResult.success(
          folders: [FavoriteFolder(id: 'shelf', name: '書架')],
          favoritedFolderIds: {},
        ),
      );
      when(
        () => preferences.saveSelectedFavoriteFolderId(
          FavoritePageMode.cloud,
          'shelf',
          sourceKey: 'jm',
        ),
      ).thenAnswer((_) async {});

      await controller.loadInitial(timeoutMessage: 'timeout');

      expect(controller.folders.single.id, 'shelf');
      expect(controller.selectedFolderId, 'shelf');
      expect(controller.comics.single.id, 'current');
      verify(
        () => preferences.saveSelectedFavoriteFolderId(
          FavoritePageMode.cloud,
          'shelf',
          sourceKey: 'jm',
        ),
      ).called(1);
      verify(
        () => source.loadFavoriteComics(
          page: 1,
          folderId: 'shelf',
          taskOrigin: any(named: 'taskOrigin'),
        ),
      ).called(1);
      verifyNever(
        () => source.loadFavoriteComics(
          page: 1,
          folderId: '0',
          taskOrigin: any(named: 'taskOrigin'),
        ),
      );
    },
  );

  for (final remainingId in ['shelf', '0', null]) {
    test(
      'cloud deletion reloads the remaining folder ($remainingId)',
      () async {
        const deletedFolder = FavoriteFolder(id: 'deleted', name: 'Deleted');
        final remainingFolders = [
          if (remainingId != null)
            FavoriteFolder(id: remainingId, name: 'Remaining'),
        ];
        when(
          () => preferences.loadSelectedFavoriteFolderId(
            FavoritePageMode.cloud,
            sourceKey: 'jm',
          ),
        ).thenAnswer((_) async => 'deleted');
        when(
          () =>
              source.loadFavoriteFolders(taskOrigin: any(named: 'taskOrigin')),
        ).thenAnswer(
          (_) async => FavoriteFoldersResult.success(
            folders: [deletedFolder, ...remainingFolders],
            favoritedFolderIds: const {},
          ),
        );
        when(
          () => preferences.saveSelectedFavoriteFolderId(
            FavoritePageMode.cloud,
            any(),
            sourceKey: 'jm',
          ),
        ).thenAnswer((_) async {});
        when(
          () => source.loadFavoriteComics(
            page: any(named: 'page'),
            folderId: any(named: 'folderId'),
            taskOrigin: any(named: 'taskOrigin'),
          ),
        ).thenAnswer((call) async {
          final id = call.namedArguments[#folderId] as String;
          return FavoriteComicsResult.success([_comic(id)]);
        });
        when(
          () => source.deleteFavoriteFolder(
            'deleted',
            taskOrigin: any(named: 'taskOrigin'),
          ),
        ).thenAnswer((_) async {});
        await controller.loadInitial(timeoutMessage: 'timeout');
        expect(controller.selectedFolderId, 'deleted');
        expect(controller.comics.single.id, 'deleted');

        final pendingFolders = Completer<FavoriteFoldersResult>();
        when(
          () =>
              source.loadFavoriteFolders(taskOrigin: any(named: 'taskOrigin')),
        ).thenAnswer((_) => pendingFolders.future);

        expect(
          await controller.deleteCurrentFolder(timeoutMessage: 'timeout'),
          isNull,
        );
        final targetId = remainingId ?? '0';
        expect(controller.selectedFolderId, targetId);
        expect(controller.comics.single.id, targetId);
        verify(
          () => source.loadFavoriteComics(
            page: 1,
            folderId: targetId,
            taskOrigin: any(named: 'taskOrigin'),
          ),
        ).called(1);
        verify(
          () => preferences.saveSelectedFavoriteFolderId(
            FavoritePageMode.cloud,
            targetId,
            sourceKey: 'jm',
          ),
        ).called(1);

        pendingFolders.complete(
          FavoriteFoldersResult.success(
            folders: remainingFolders,
            favoritedFolderIds: const {},
          ),
        );
        await _settle();
        expect(controller.selectedFolderId, targetId);
        expect(controller.folders.single.id, targetId);
        expect(controller.comics.single.id, targetId);
      },
    );
  }

  for (final remainingId in ['0', 'shelf']) {
    for (final refreshStage in ['completed', 'folders', 'comics']) {
      test(
        'cloud deletion survives a concurrent refresh ($remainingId, $refreshStage)',
        () async {
          const deletedFolder = FavoriteFolder(id: 'deleted', name: 'Deleted');
          final remainingFolder = FavoriteFolder(
            id: remainingId,
            name: 'Remaining',
          );
          final originalFolders = FavoriteFoldersResult.success(
            folders: [deletedFolder, remainingFolder],
            favoritedFolderIds: const {},
          );
          when(
            () => preferences.loadSelectedFavoriteFolderId(
              FavoritePageMode.cloud,
              sourceKey: 'jm',
            ),
          ).thenAnswer((_) async => 'deleted');
          when(
            () => preferences.saveSelectedFavoriteFolderId(
              FavoritePageMode.cloud,
              any(),
              sourceKey: 'jm',
            ),
          ).thenAnswer((_) async {});
          when(
            () => source.loadFavoriteFolders(
              taskOrigin: any(named: 'taskOrigin'),
            ),
          ).thenAnswer((_) async => originalFolders);
          when(
            () => source.loadFavoriteComics(
              page: any(named: 'page'),
              folderId: any(named: 'folderId'),
              taskOrigin: any(named: 'taskOrigin'),
            ),
          ).thenAnswer((call) async {
            final id = call.namedArguments[#folderId] as String;
            return FavoriteComicsResult.success([_comic(id)]);
          });
          await controller.loadInitial(timeoutMessage: 'timeout');

          final pendingDelete = Completer<void>();
          when(
            () => source.deleteFavoriteFolder(
              'deleted',
              taskOrigin: any(named: 'taskOrigin'),
            ),
          ).thenAnswer((_) => pendingDelete.future);
          final deletion = controller.deleteCurrentFolder(
            timeoutMessage: 'timeout',
          );

          final pendingFolders = Completer<FavoriteFoldersResult>();
          final pendingComics = Completer<FavoriteComicsResult>();
          if (refreshStage == 'folders') {
            when(
              () => source.loadFavoriteFolders(
                taskOrigin: any(named: 'taskOrigin'),
              ),
            ).thenAnswer((_) => pendingFolders.future);
          } else if (refreshStage == 'comics') {
            when(
              () => source.loadFavoriteComics(
                page: 1,
                folderId: 'deleted',
                taskOrigin: any(named: 'taskOrigin'),
              ),
            ).thenAnswer((_) => pendingComics.future);
          }
          final refresh = controller.refresh(timeoutMessage: 'timeout');
          if (refreshStage == 'completed') {
            await refresh;
          } else {
            await _settle();
            expect(controller.refreshing, isTrue);
          }

          when(
            () => source.loadFavoriteFolders(
              taskOrigin: any(named: 'taskOrigin'),
            ),
          ).thenAnswer(
            (_) async => FavoriteFoldersResult.success(
              folders: [remainingFolder],
              favoritedFolderIds: const {},
            ),
          );
          pendingDelete.complete();
          expect(await deletion, isNull);
          await _settle();

          void expectRemainingFolder() {
            expect(controller.selectedFolderId, remainingId);
            expect(controller.folders.single.id, remainingId);
            expect(controller.comics.single.id, remainingId);
            expect(controller.initialLoading, isFalse);
            expect(controller.refreshing, isFalse);
            expect(controller.loadingFolders, isFalse);
          }

          expectRemainingFolder();
          if (refreshStage == 'folders') {
            pendingFolders.complete(originalFolders);
          } else if (refreshStage == 'comics') {
            pendingComics.complete(
              FavoriteComicsResult.success([_comic('stale deleted')]),
            );
          }
          await refresh;
          expectRemainingFolder();
          verify(
            () => source.loadFavoriteComics(
              page: 1,
              folderId: remainingId,
              taskOrigin: any(named: 'taskOrigin'),
            ),
          ).called(1);
          verify(
            () => preferences.saveSelectedFavoriteFolderId(
              FavoritePageMode.cloud,
              remainingId,
              sourceKey: 'jm',
            ),
          ).called(1);
        },
      );
    }
  }

  test('local folder refresh survives a concurrent sort change', () async {
    await controller.loadInitial(timeoutMessage: 'timeout');
    await controller.toggleMode(timeoutMessage: 'timeout');
    final pending = Completer<FavoriteFoldersResult>();
    when(
      () => local.loadFavoriteFolders(sourceKey: 'jm'),
    ).thenAnswer((_) => pending.future);
    when(
      () => preferences.saveSortOrder('readNewest'),
    ).thenAnswer((_) async {});
    when(
      () => local.loadFavoriteComics(
        page: 1,
        folderId: 'local',
        sortOrder: 'readNewest',
        sourceKey: 'jm',
      ),
    ).thenAnswer((_) async => FavoriteComicsResult.success([_comic('sorted')]));

    final reload = controller.reloadFolders();
    await controller.changeSortOrder('readNewest', timeoutMessage: 'timeout');
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

  test(
    'migrates a local sort once and preserves it after changing source',
    () async {
      var savedOrder = 'mp';
      when(
        () => preferences.loadSortOrder(),
      ).thenAnswer((_) async => savedOrder);
      when(() => preferences.saveSortOrder(any())).thenAnswer((call) async {
        savedOrder = call.positionalArguments.single as String;
      });
      when(() => source.supportFavoriteFolderAdd).thenReturn(false);
      when(() => source.favoriteSortOrders).thenReturn([]);
      when(
        () => preferences.loadFavoritePageMode(sourceKey: 'picacg'),
      ).thenAnswer((_) async => FavoritePageMode.local);
      when(
        () => local.loadFavoriteComics(
          page: 1,
          folderId: 'local',
          sortOrder: 'readNewest',
          sourceKey: any(named: 'sourceKey'),
        ),
      ).thenAnswer(
        (_) async => FavoriteComicsResult.success([_comic('updated')]),
      );
      await controller.loadInitial(timeoutMessage: 'timeout');
      await controller.toggleMode(timeoutMessage: 'timeout');
      expect(savedOrder, 'readNewest');
      expect(controller.appBarActionsState.currentSortOrder, 'readNewest');
      activeSource = 'picacg';
      sourceChanged();
      await _settle();
      expect(controller.mode, FavoritePageMode.local);
      expect(controller.appBarActionsState.currentSortOrder, 'readNewest');
      expect(controller.appBarActionsState.sortOrders, [
        'savedNewest',
        'savedOldest',
        'readNewest',
      ]);
      expect(controller.comics.single.id, 'updated');
      verify(() => preferences.saveSortOrder('readNewest')).called(1);
    },
  );

  test('empty local directory refresh clears the live comic list', () async {
    await controller.loadInitial(timeoutMessage: 'timeout');
    await controller.toggleMode(timeoutMessage: 'timeout');
    expect(controller.comics, isNotEmpty);
    when(() => local.loadFavoriteFolders(sourceKey: 'jm')).thenAnswer(
      (_) async => const FavoriteFoldersResult.success(
        folders: [],
        favoritedFolderIds: {},
      ),
    );
    when(
      () => preferences.saveSelectedFavoriteFolderId(
        FavoritePageMode.local,
        '',
        sourceKey: 'jm',
      ),
    ).thenAnswer((_) async {});
    await controller.reloadFolders();
    expect(controller.folders, isEmpty);
    expect(controller.selectedFolderId, '');
    expect(controller.comics, isEmpty);
    expect(controller.errorMessage, isNull);
    expect(controller.hasMore, isFalse);
    expect(controller.loadingFolders, isFalse);
  });

  test(
    'switching from local mode to another source restores its cloud order',
    () async {
      when(() => source.supportFavoriteFolderAdd).thenReturn(false);
      await controller.loadInitial(timeoutMessage: 'timeout');
      await controller.toggleMode(timeoutMessage: 'timeout');
      expect(controller.mode, FavoritePageMode.local);
      when(() => source.favoriteSortOrders).thenReturn(['score', 'recent']);
      when(() => source.favoriteSortOrder).thenReturn('score');
      activeSource = 'picacg';
      sourceChanged();
      await _settle();
      expect(controller.mode, FavoritePageMode.cloud);
      expect(controller.appBarActionsState.currentSortOrder, 'score');
    },
  );

  test(
    'cloud sort follows changed declarations without changing source',
    () async {
      when(() => source.supportFavoriteFolderAdd).thenReturn(false);
      await controller.loadInitial(timeoutMessage: 'timeout');
      when(() => source.favoriteSortOrders).thenReturn(['score']);
      when(() => source.favoriteSortOrder).thenReturn('score');
      sourceChanged();
      expect(controller.appBarActionsState.currentSortOrder, 'score');
    },
  );

  for (final initialOrder in ['mr', 'mr_reverse']) {
    test(
      'changing $initialOrder direction clears data and restarts paging',
      () async {
        final nextOrder = initialOrder == 'mr' ? 'mr_reverse' : 'mr';
        var order = initialOrder;
        final requests = <(String, int)>[];
        final oldPage = Completer<FavoriteComicsResult>();
        final newPage = Completer<FavoriteComicsResult>();
        when(() => source.favoriteSortOrders).thenReturn(['mr', 'mr_reverse']);
        when(() => source.favoriteSortOrder).thenAnswer((_) => order);
        when(() => source.setFavoriteSortOrder(nextOrder)).thenAnswer((
          _,
        ) async {
          order = nextOrder;
        });
        when(
          () => source.loadFavoriteComics(
            page: any(named: 'page'),
            folderId: any(named: 'folderId'),
            taskOrigin: any(named: 'taskOrigin'),
          ),
        ).thenAnswer((call) async {
          final page = call.namedArguments[#page] as int;
          requests.add((order, page));
          if (order == initialOrder && page == 3) return oldPage.future;
          if (order == nextOrder && page == 1) return newPage.future;
          return FavoriteComicsResult.success([
            _comic('$order-$page'),
          ], maxPage: 4);
        });
        await controller.loadInitial(timeoutMessage: 'timeout');
        await controller.loadMore(timeoutMessage: 'timeout');
        expect(controller.comics.map((c) => c.id), [
          '$initialOrder-1',
          '$initialOrder-2',
        ]);
        final pendingOld = controller.loadMore(timeoutMessage: 'timeout');
        final change = controller.changeSortOrder(
          nextOrder,
          timeoutMessage: 'timeout',
        );
        await _settle();
        expect(controller.comics, isEmpty);
        expect(controller.initialLoading, isTrue);
        expect(controller.loadingMore, isFalse);
        expect(requests.last, (nextOrder, 1));

        oldPage.complete(
          FavoriteComicsResult.success([_comic('stale')], maxPage: 4),
        );
        await pendingOld;
        expect(controller.comics, isEmpty);
        newPage.complete(
          FavoriteComicsResult.success([_comic('$nextOrder-1')], maxPage: 4),
        );
        expect(await change, isNull);
        expect(controller.comics.single.id, '$nextOrder-1');
        await controller.loadMore(timeoutMessage: 'timeout');
        expect(requests, [
          (initialOrder, 1),
          (initialOrder, 2),
          (initialOrder, 3),
          (nextOrder, 1),
          (nextOrder, 2),
        ]);
        expect(controller.comics.map((c) => c.id), [
          '$nextOrder-1',
          '$nextOrder-2',
        ]);
      },
    );
  }

  test('older folder refresh cannot overwrite the latest folders', () async {
    await controller.loadInitial(timeoutMessage: 'timeout');
    final pending = Completer<FavoriteFoldersResult>();
    when(
      () => source.loadFavoriteFolders(taskOrigin: any(named: 'taskOrigin')),
    ).thenAnswer((_) => pending.future);
    final oldReload = controller.reloadFolders();
    when(
      () => source.loadFavoriteFolders(taskOrigin: any(named: 'taskOrigin')),
    ).thenAnswer(
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
        () => source.loadFavoriteFolders(taskOrigin: any(named: 'taskOrigin')),
      ).thenAnswer((_) => pending.future);
      final reload = controller.reloadFolders();
      if (transition == 'logout') {
        controller.resetLoggedOut();
      } else if (transition == 'mode') {
        await controller.toggleMode(timeoutMessage: 'timeout');
      } else {
        activeSource = 'picacg';
        when(
          () =>
              source.loadFavoriteFolders(taskOrigin: any(named: 'taskOrigin')),
        ).thenAnswer(
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
        () => source.loadFavoriteComics(
          page: 1,
          folderId: '0',
          taskOrigin: any(named: 'taskOrigin'),
        ),
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
      () => source.loadFavoriteComics(
        page: 1,
        folderId: '0',
        taskOrigin: any(named: 'taskOrigin'),
      ),
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
      () => source.loadFavoriteComics(
        page: 1,
        folderId: 'old-source-folder',
        taskOrigin: any(named: 'taskOrigin'),
      ),
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
