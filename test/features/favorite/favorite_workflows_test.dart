import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/favorite/state/favorite_folder_state.dart';
import 'package:hazuki/features/favorite/state/favorite_sort_state.dart';
import 'package:hazuki/features/favorite/support/favorite_cloud_flow.dart';
import 'package:hazuki/features/favorite/support/favorite_folder_coordinator.dart';
import 'package:hazuki/features/favorite/support/favorite_local_flow.dart';
import 'package:hazuki/features/favorite/support/favorite_selection_store.dart';
import 'package:hazuki/features/favorite/support/favorite_sort_flow.dart';
import 'package:hazuki/features/favorite/support/favorite_source_policy.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/local_favorites/local_favorites_contracts.dart';
import 'package:hazuki/services/local_favorites/local_favorites_preferences_store.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:mocktail/mocktail.dart';

class _State extends Fake implements FavoriteFolderState, FavoriteSortState {
  _State(this.events);

  final List<String> events;
  @override
  FavoritePageMode mode = FavoritePageMode.cloud;
  @override
  List<FavoriteFolder> folders = const [defaultCloudFavoriteFolder];
  @override
  String selectedCloudFolderId = '0';
  @override
  String selectedLocalFolderId = 'local-1';
  @override
  bool loadingFolders = false;
  @override
  String favoriteSortOrder = 'mr';
  @override
  String get selectedFolderId => mode == FavoritePageMode.local
      ? selectedLocalFolderId
      : selectedCloudFolderId;
  @override
  void clearComicsForEmptyFolders() => events.add('empty');
}

class _Source extends Mock implements SourceFavoriteGateway {}

class _Local extends Mock implements LocalFavoritesRepository {}

class _Preferences extends Mock implements LocalFavoritesPreferencesStore {}

FavoriteFolder _folder(String id, String name, FavoriteFolderSource source) =>
    FavoriteFolder(id: id, name: name, source: source);

FavoriteFoldersResult _result(List<FavoriteFolder> folders) =>
    FavoriteFoldersResult.success(
      folders: folders,
      favoritedFolderIds: const {},
    );

void main() {
  setUpAll(() => registerFallbackValue(FavoritePageMode.cloud));
  late _Source source;
  late _Local local;
  late _Preferences preferences;
  late _State state;
  late List<String> events;
  late FavoriteFolderCoordinator folders;
  late FavoriteSortFlow sort;
  late List<FavoriteFolder> cloudFolders;
  late List<FavoriteFolder> localFolders;
  late String sourceKey;
  var disposed = false;
  Future<void>? selectionWait;
  String? localReloadError;
  Object? selectionError;
  Object? cloudReloadError;
  void Function(String)? forwardedFolderError;

  setUp(() {
    events = [];
    state = _State(events);
    source = _Source();
    local = _Local();
    preferences = _Preferences();
    sourceKey = 'jm';
    disposed = false;
    selectionWait = null;
    selectionError = null;
    localReloadError = null;
    cloudReloadError = null;
    forwardedFolderError = null;
    cloudFolders = [
      defaultCloudFavoriteFolder,
      _folder('cloud-1', 'one', FavoriteFolderSource.cloud),
    ];
    localFolders = [_folder('local-1', 'one', FavoriteFolderSource.local)];
    when(() => source.supportFavoriteFolderLoad).thenReturn(true);
    when(() => source.favoriteSortOrders).thenReturn(['mr', 'mp']);
    when(source.loadFavoriteFolders).thenAnswer((_) async {
      events.add('cloud.load');
      return _result(cloudFolders);
    });
    when(
      () => local.loadFavoriteFolders(sourceKey: any(named: 'sourceKey')),
    ).thenAnswer((_) async {
      events.add('local.load');
      return _result(localFolders);
    });
    when(() => source.addFavoriteFolder(any())).thenAnswer((call) async {
      events.add('cloud.add:${call.positionalArguments.single}');
    });
    when(
      () => local.addFavoriteFolder(any(), sourceKey: any(named: 'sourceKey')),
    ).thenAnswer((call) async {
      events.add(
        'local.add:${call.positionalArguments.single}:${call.namedArguments[#sourceKey]}',
      );
    });
    when(
      () => local.renameFavoriteFolder(
        folderId: any(named: 'folderId'),
        name: any(named: 'name'),
        sourceKey: any(named: 'sourceKey'),
      ),
    ).thenAnswer((call) async {
      events.add(
        'local.rename:${call.namedArguments[#folderId]}:${call.namedArguments[#name]}:${call.namedArguments[#sourceKey]}',
      );
    });
    when(() => source.deleteFavoriteFolder(any())).thenAnswer((call) async {
      events.add('cloud.delete:${call.positionalArguments.single}');
    });
    when(
      () =>
          local.deleteFavoriteFolder(any(), sourceKey: any(named: 'sourceKey')),
    ).thenAnswer((call) async {
      events.add(
        'local.delete:${call.positionalArguments.single}:${call.namedArguments[#sourceKey]}',
      );
    });
    when(
      () => preferences.saveSelectedFavoriteFolderId(
        any(),
        any(),
        sourceKey: any(named: 'sourceKey'),
      ),
    ).thenAnswer((call) async {
      events.add(
        'save:${(call.positionalArguments[0] as FavoritePageMode).name}:${call.positionalArguments[1]}:${call.namedArguments[#sourceKey]}',
      );
    });
    when(() => preferences.saveSortOrder(any())).thenAnswer((call) async {
      events.add('local.sort:${call.positionalArguments.single}');
    });
    when(() => source.setFavoriteSortOrder(any())).thenAnswer((call) async {
      events.add('cloud.sort:${call.positionalArguments.single}');
    });
    final cloudFlow = FavoriteCloudFlow(source);
    final localFlow = FavoriteLocalFlow(
      repository: local,
      preferences: preferences,
    );
    folders = FavoriteFolderCoordinator(
      state: state,
      cloudFlow: cloudFlow,
      localFlow: localFlow,
      selectionStore: FavoriteSelectionStore(preferences),
      readSourceKey: () => sourceKey,
      isDisposed: () => disposed,
      notify: () {
        if (!disposed) {
          events.add(
            'notify:${state.loadingFolders}:${state.selectedFolderId}',
          );
        }
      },
      selectFolder: (id, {required timeoutMessage, forceReload = false}) async {
        events.add('select:$id:$timeoutMessage');
        if (selectionError != null) throw selectionError!;
        if (selectionWait != null) await selectionWait;
      },
    );
    sort = FavoriteSortFlow(
      state: state,
      cloudFlow: cloudFlow,
      localFlow: localFlow,
      sourcePolicy: FavoriteSourcePolicy(
        presentationFor: (_) => {
          'favoriteOrderAliases': {'old': 'mp'},
          'favoriteDefaultOrder': 'mr',
        },
      ),
      readSourceKey: () => sourceKey,
      isDisposed: () => disposed,
      reloadLocalComicsAfterSort: () async {
        expect(state.favoriteSortOrder, 'updatedNewest');
        events.add('reload.local');
        return localReloadError;
      },
      resetForReload: () {
        expect(state.favoriteSortOrder, 'mp');
        events.add('reset.cloud');
      },
      loadInitial: ({required timeoutMessage, onFolderLoadError}) async {
        events.add('reload.cloud:$timeoutMessage');
        forwardedFolderError = onFolderLoadError;
        if (cloudReloadError != null) throw cloudReloadError!;
      },
    );
  });

  group('folder workflows', () {
    test(
      'unsupported cloud directories reset and persist the default selection',
      () async {
        state.selectedCloudFolderId = 'missing';
        when(() => source.supportFavoriteFolderLoad).thenReturn(false);
        await folders.reloadFolders();
        expect(state.folders, [defaultCloudFavoriteFolder]);
        expect(events, ['save:cloud:0:jm', 'notify:false:0']);
        verifyNever(source.loadFavoriteFolders);
      },
    );

    test('empty cloud results retain the default directory', () async {
      cloudFolders = [];
      await folders.reloadFolders();
      expect(state.folders, [defaultCloudFavoriteFolder]);
      expect(events, ['notify:true:0', 'cloud.load', 'notify:false:0']);
    });

    test(
      'missing selection falls back and persists before notifying',
      () async {
        state.selectedCloudFolderId = 'missing';
        await folders.reloadFolders();
        expect(state.selectedCloudFolderId, '0');
        expect(events, [
          'notify:true:missing',
          'cloud.load',
          'save:cloud:0:jm',
          'notify:false:0',
        ]);
      },
    );

    test(
      'cloud directory errors finish loading before the error callback',
      () async {
        when(source.loadFavoriteFolders).thenAnswer(
          (_) async => const FavoriteFoldersResult.error('load failed'),
        );
        await folders.reloadFolders(
          onError: (error) {
            expect(state.loadingFolders, isFalse);
            events.add('error:$error');
          },
        );
        expect(events, [
          'notify:true:0',
          'notify:false:0',
          'error:load failed',
        ]);
      },
    );

    test('empty local directories clear selection and comic state', () async {
      state.mode = FavoritePageMode.local;
      localFolders = [];
      await folders.reloadFolders();
      expect(state.selectedLocalFolderId, '');
      expect(state.folders, isEmpty);
      expect(events, [
        'notify:true:local-1',
        'local.load',
        'save:local::jm',
        'empty',
        'notify:false:',
      ]);
    });

    test(
      'local directory reload can suppress intermediate notifications',
      () async {
        state.mode = FavoritePageMode.local;
        await folders.reloadLocalFolders(notifyChanges: false);
        expect(state.folders, localFolders);
        expect(state.loadingFolders, isFalse);
        expect(events, ['local.load']);
      },
    );

    for (final mode in FavoritePageMode.values) {
      test(
        'creates a $mode folder then selects the first matching name',
        () async {
          state.mode = mode;
          expect(
            await folders.createFolder('one', timeoutMessage: 'timeout'),
            isNull,
          );
          expect(
            events.first,
            mode == FavoritePageMode.local
                ? 'local.add:one:jm'
                : 'cloud.add:one',
          );
          expect(
            events.last,
            mode == FavoritePageMode.local
                ? 'select:local-1:timeout'
                : 'select:cloud-1:timeout',
          );
        },
      );
    }

    test(
      'create waits for selection completion and returns selection errors',
      () async {
        final pending = Completer<void>();
        selectionWait = pending.future;
        var completed = false;
        final create = folders
            .createFolder('one', timeoutMessage: 'timeout')
            .then((result) {
              completed = true;
              return result;
            });
        await Future<void>.delayed(Duration.zero);
        expect(completed, isFalse);
        pending.complete();
        expect(await create, isNull);
        selectionWait = null;
        selectionError = StateError('selection failed');
        expect(
          await folders.createFolder('one', timeoutMessage: ''),
          contains('selection failed'),
        );
      },
    );

    test(
      'create converts persistence failures to the existing error string',
      () async {
        state.selectedCloudFolderId = 'missing';
        when(
          () => preferences.saveSelectedFavoriteFolderId(
            FavoritePageMode.cloud,
            '0',
            sourceKey: 'jm',
          ),
        ).thenThrow(StateError('save failed'));
        expect(
          await folders.createFolder('one', timeoutMessage: ''),
          contains('save failed'),
        );
        expect(events.where((event) => event.startsWith('select:')), isEmpty);
      },
    );

    test('local rename trims the id and reloads directories', () async {
      state.mode = FavoritePageMode.local;
      expect(await folders.renameLocalFolder(' local-1 ', 'renamed'), isNull);
      expect(events, [
        'local.rename:local-1:renamed:jm',
        'notify:true:local-1',
        'local.load',
        'notify:false:local-1',
      ]);
    });

    test('rename ignores cloud mode and empty local ids', () async {
      await folders.renameLocalFolder('cloud-1', 'renamed');
      state.mode = FavoritePageMode.local;
      await folders.renameLocalFolder('  ', 'renamed');
      expect(events, isEmpty);
    });

    test('rename failure is returned without a directory reload', () async {
      state.mode = FavoritePageMode.local;
      when(
        () => local.renameFavoriteFolder(
          folderId: 'local-1',
          name: 'renamed',
          sourceKey: 'jm',
        ),
      ).thenThrow(StateError('rename failed'));
      expect(
        await folders.renameLocalFolder('local-1', 'renamed'),
        contains('rename failed'),
      );
      expect(events, isEmpty);
    });

    test('rename completion after disposal does not reload', () async {
      state.mode = FavoritePageMode.local;
      final pending = Completer<void>();
      when(
        () => local.renameFavoriteFolder(
          folderId: 'local-1',
          name: 'renamed',
          sourceKey: 'jm',
        ),
      ).thenAnswer((_) => pending.future);
      final rename = folders.renameLocalFolder('local-1', 'renamed');
      disposed = true;
      pending.complete();
      expect(await rename, isNull);
      expect(events, isEmpty);
    });

    test(
      'default cloud and empty local directories cannot be deleted',
      () async {
        await folders.deleteCurrentFolder(timeoutMessage: 'timeout');
        state.mode = FavoritePageMode.local;
        state.selectedLocalFolderId = '';
        await folders.deleteCurrentFolder(timeoutMessage: 'timeout');
        expect(events, isEmpty);
      },
    );

    test('local deletion persists the fallback before selecting it', () async {
      state.mode = FavoritePageMode.local;
      localFolders = [
        _folder('local-2', 'remaining', FavoriteFolderSource.local),
      ];
      expect(
        await folders.deleteCurrentFolder(timeoutMessage: 'timeout'),
        isNull,
      );
      expect(events, [
        'local.delete:local-1:jm',
        'save:local::jm',
        'notify:true:',
        'local.load',
        'save:local:local-2:jm',
        'notify:false:local-2',
        'select:local-2:timeout',
      ]);
    });

    for (final action in ['create', 'rename', 'delete']) {
      test(
        'local $action completion cannot mutate a newly selected source',
        () async {
          state.mode = FavoritePageMode.local;
          state.folders = localFolders;
          final pending = Completer<void>();
          when(
            () => local.addFavoriteFolder('new', sourceKey: 'jm'),
          ).thenAnswer((_) => pending.future);
          when(
            () => local.renameFavoriteFolder(
              folderId: 'local-1',
              name: 'new',
              sourceKey: 'jm',
            ),
          ).thenAnswer((_) => pending.future);
          when(
            () => local.deleteFavoriteFolder('local-1', sourceKey: 'jm'),
          ).thenAnswer((_) => pending.future);

          final mutation = switch (action) {
            'create' => folders.createFolder('new', timeoutMessage: 'timeout'),
            'rename' => folders.renameLocalFolder('local-1', 'new'),
            _ => folders.deleteCurrentFolder(timeoutMessage: 'timeout'),
          };
          sourceKey = 'other';
          folders.invalidate();
          state.folders = [
            _folder('other-folder', 'Other', FavoriteFolderSource.local),
          ];
          state.selectedLocalFolderId = 'other-folder';
          pending.complete();
          expect(await mutation, isNull);
          expect(state.folders.single.id, 'other-folder');
          expect(state.selectedLocalFolderId, 'other-folder');
          expect(events, isEmpty);
          verifyNever(
            () => local.loadFavoriteFolders(sourceKey: any(named: 'sourceKey')),
          );
        },
      );
    }

    test(
      'cloud deletion launches directory refresh without waiting for it',
      () async {
        state.selectedCloudFolderId = 'cloud-1';
        state.folders = cloudFolders;
        final pending = Completer<FavoriteFoldersResult>();
        when(source.loadFavoriteFolders).thenAnswer((_) {
          events.add('cloud.load');
          return pending.future;
        });
        expect(
          await folders.deleteCurrentFolder(timeoutMessage: 'timeout'),
          isNull,
        );
        // The injected selection callback records requests; the real controller
        // owns persisting and updating the selected ID.
        expect(state.selectedCloudFolderId, 'cloud-1');
        expect(state.loadingFolders, isTrue);
        expect(events, [
          'cloud.delete:cloud-1',
          'select:0:timeout',
          'notify:true:cloud-1',
          'cloud.load',
        ]);
        pending.complete(_result([defaultCloudFavoriteFolder]));
        await Future<void>.delayed(Duration.zero);
        expect(state.loadingFolders, isFalse);
        expect(events.last, 'notify:false:0');
      },
    );

    test('delete failure does not persist a fallback selection', () async {
      state.selectedCloudFolderId = 'cloud-1';
      when(
        () => source.deleteFavoriteFolder('cloud-1'),
      ).thenThrow(StateError('delete failed'));
      expect(
        await folders.deleteCurrentFolder(timeoutMessage: ''),
        contains('delete failed'),
      );
      expect(state.selectedCloudFolderId, 'cloud-1');
      expect(events, isEmpty);
    });

    test(
      'failed cloud deletion leaves a pending folder refresh valid',
      () async {
        state.selectedCloudFolderId = 'cloud-1';
        state.folders = cloudFolders;
        final pending = Completer<FavoriteFoldersResult>();
        when(source.loadFavoriteFolders).thenAnswer((_) => pending.future);
        final reload = folders.reloadFolders();
        when(
          () => source.deleteFavoriteFolder('cloud-1'),
        ).thenThrow(StateError('delete failed'));

        expect(
          await folders.deleteCurrentFolder(timeoutMessage: 'timeout'),
          contains('delete failed'),
        );
        final refreshedFolders = [
          defaultCloudFavoriteFolder,
          _folder('cloud-1', 'renamed', FavoriteFolderSource.cloud),
        ];
        pending.complete(_result(refreshedFolders));
        await reload;

        expect(state.folders, same(refreshedFolders));
        expect(state.selectedCloudFolderId, 'cloud-1');
        expect(state.loadingFolders, isFalse);
      },
    );

    for (final transition in ['source', 'mode', 'invalidate', 'dispose']) {
      test(
        'cloud deletion ignores a stale completion after $transition',
        () async {
          state.selectedCloudFolderId = 'cloud-1';
          state.folders = cloudFolders;
          final pending = Completer<void>();
          when(
            () => source.deleteFavoriteFolder('cloud-1'),
          ).thenAnswer((_) => pending.future);

          final deletion = folders.deleteCurrentFolder(
            timeoutMessage: 'timeout',
          );
          if (transition == 'source') sourceKey = 'other';
          if (transition == 'mode') state.mode = FavoritePageMode.local;
          if (transition == 'invalidate') folders.invalidate();
          if (transition == 'dispose') disposed = true;
          pending.complete();

          expect(await deletion, isNull);
          expect(state.folders, same(cloudFolders));
          expect(events, isEmpty);
          verifyNever(source.loadFavoriteFolders);
        },
      );
    }

    for (final transition in ['source', 'mode', 'invalidate', 'dispose']) {
      test('late directory results are discarded after $transition', () async {
        final previous = state.folders;
        final pending = Completer<FavoriteFoldersResult>();
        when(source.loadFavoriteFolders).thenAnswer((_) => pending.future);
        final reload = folders.reloadFolders();
        if (transition == 'source') sourceKey = 'other';
        if (transition == 'mode') state.mode = FavoritePageMode.local;
        if (transition == 'invalidate') folders.invalidate();
        if (transition == 'dispose') disposed = true;
        pending.complete(
          _result([_folder('late', 'late', FavoriteFolderSource.cloud)]),
        );
        await reload;
        expect(state.folders, same(previous));
        expect(events, ['notify:true:0']);
      });
    }
  });

  group('sort workflows', () {
    for (final mode in FavoritePageMode.values) {
      test('$mode sort aliases persist before reloading comics', () async {
        state.mode = mode;
        void onError(String error) {}
        expect(
          await sort.changeSortOrder(
            mode == FavoritePageMode.local ? ' updatedNewest ' : ' old ',
            timeoutMessage: 'timeout',
            onFolderLoadError: onError,
          ),
          isNull,
        );
        expect(
          state.favoriteSortOrder,
          mode == FavoritePageMode.local ? 'updatedNewest' : 'mp',
        );
        expect(
          events,
          mode == FavoritePageMode.local
              ? ['local.sort:updatedNewest', 'reload.local']
              : ['cloud.sort:mp', 'reset.cloud', 'reload.cloud:timeout'],
        );
        if (mode == FavoritePageMode.cloud) {
          expect(forwardedFolderError, same(onError));
        }
      });

      test('$mode repeated sort does not persist or reload', () async {
        state.mode = mode;
        state.favoriteSortOrder = mode == FavoritePageMode.local
            ? 'savedNewest'
            : 'mr';
        expect(
          await sort.changeSortOrder(
            ' ${state.favoriteSortOrder} ',
            timeoutMessage: '',
          ),
          isNull,
        );
        expect(events, isEmpty);
      });

      test(
        '$mode sort completion after disposal does not update state',
        () async {
          state.mode = mode;
          final pending = Completer<void>();
          if (mode == FavoritePageMode.local) {
            when(
              () => preferences.saveSortOrder('updatedNewest'),
            ).thenAnswer((_) => pending.future);
          } else {
            when(
              () => source.setFavoriteSortOrder('mp'),
            ).thenAnswer((_) => pending.future);
          }
          final change = sort.changeSortOrder(
            mode == FavoritePageMode.local ? 'updatedNewest' : 'mp',
            timeoutMessage: 'timeout',
          );
          disposed = true;
          pending.complete();
          expect(await change, isNull);
          expect(state.favoriteSortOrder, 'mr');
          expect(events, isEmpty);
        },
      );
    }

    test('local list errors are returned through the callback', () async {
      state.mode = FavoritePageMode.local;
      localReloadError = 'list failed';
      expect(
        await sort.changeSortOrder('updatedNewest', timeoutMessage: ''),
        'list failed',
      );
      expect(events, ['local.sort:updatedNewest', 'reload.local']);
    });

    test(
      'cloud reload exceptions keep the persisted sort and return an error',
      () async {
        cloudReloadError = StateError('reload failed');
        expect(
          await sort.changeSortOrder('mp', timeoutMessage: ''),
          contains('reload failed'),
        );
        expect(state.favoriteSortOrder, 'mp');
        expect(events, ['cloud.sort:mp', 'reset.cloud', 'reload.cloud:']);
      },
    );

    test(
      'sort persistence failure leaves the selected order unchanged',
      () async {
        state.mode = FavoritePageMode.local;
        when(
          () => preferences.saveSortOrder('updatedNewest'),
        ).thenThrow(StateError('save failed'));
        expect(
          await sort.changeSortOrder('updatedNewest', timeoutMessage: ''),
          contains('save failed'),
        );
        expect(state.favoriteSortOrder, 'mr');
        expect(events, isEmpty);
      },
    );
  });
}
