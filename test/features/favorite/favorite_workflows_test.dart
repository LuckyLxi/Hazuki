import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/favorite/state/favorite_page_controller.dart';
import 'package:hazuki/features/favorite/state/favorite_folder_state.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/local_favorites/local_favorites_contracts.dart';
import 'package:hazuki/services/local_favorites/local_favorites_preferences_store.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fake_source_task_control.dart';

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
Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  setUpAll(() => registerFallbackValue(FavoritePageMode.cloud));
  late _Source source;
  late _Local local;
  late _Preferences preferences;
  late FavoritePageController controller;
  late List<String> events;
  late List<FavoriteFolder> cloudFolders;
  late List<FavoriteFolder> localFolders;
  late String sourceKey;
  late FavoritePageMode savedMode;
  late String savedCloudId;
  late String savedLocalId;
  var disposed = false;

  setUp(() {
    source = _Source();
    local = _Local();
    preferences = _Preferences();
    events = [];
    sourceKey = 'jm';
    savedMode = FavoritePageMode.cloud;
    savedCloudId = '0';
    savedLocalId = 'local-1';
    disposed = false;
    cloudFolders = [
      defaultCloudFavoriteFolder,
      _folder('cloud-1', 'one', FavoriteFolderSource.cloud),
    ];
    localFolders = [_folder('local-1', 'one', FavoriteFolderSource.local)];
    when(() => source.activeSourceKey).thenAnswer((_) => sourceKey);
    when(
      () => source.cloudFavoritesChangedStream,
    ).thenAnswer((_) => const Stream<void>.empty());
    when(() => source.isLogged).thenReturn(true);
    when(() => source.supportFavoriteFolderLoad).thenReturn(true);
    when(() => source.supportFavoriteFolderRename).thenReturn(false);
    when(() => source.favoriteSortOrders).thenReturn(['mr']);
    when(() => source.favoriteSortOrder).thenReturn('mr');
    when(source.ensureInitialized).thenAnswer((_) async {});
    when(
      () => source.loadFavoriteFolders(taskOrigin: any(named: 'taskOrigin')),
    ).thenAnswer((_) async {
      events.add('cloud.load');
      return _result(cloudFolders);
    });
    when(
      () => local.loadFavoriteFolders(sourceKey: any(named: 'sourceKey')),
    ).thenAnswer((_) async {
      events.add('local.load');
      return _result(localFolders);
    });
    when(
      () => source.loadFavoriteComics(
        page: any(named: 'page'),
        folderId: any(named: 'folderId'),
        taskOrigin: any(named: 'taskOrigin'),
      ),
    ).thenAnswer((call) async {
      events.add('comics:${call.namedArguments[#folderId]}');
      return FavoriteComicsResult.success(const [], maxPage: 1);
    });
    when(
      () => local.loadFavoriteComics(
        page: any(named: 'page'),
        folderId: any(named: 'folderId'),
        sortOrder: any(named: 'sortOrder'),
        sourceKey: any(named: 'sourceKey'),
      ),
    ).thenAnswer((call) async {
      events.add('comics:${call.namedArguments[#folderId]}');
      return FavoriteComicsResult.success(const [
        ExploreComic(
          id: 'comic',
          sourceKey: 'jm',
          title: 'comic',
          subTitle: '',
          cover: '',
        ),
      ]);
    });
    when(
      () =>
          preferences.loadFavoritePageMode(sourceKey: any(named: 'sourceKey')),
    ).thenAnswer((_) async => savedMode);
    when(
      () => preferences.loadSelectedFavoriteFolderId(
        any(),
        sourceKey: any(named: 'sourceKey'),
      ),
    ).thenAnswer(
      (call) async => call.positionalArguments[0] == FavoritePageMode.cloud
          ? savedCloudId
          : savedLocalId,
    );
    when(
      () => preferences.saveFavoritePageMode(
        any(),
        sourceKey: any(named: 'sourceKey'),
      ),
    ).thenAnswer((_) async {});
    when(preferences.loadSortOrder).thenAnswer((_) async => 'savedNewest');
    when(() => preferences.saveSortOrder(any())).thenAnswer((_) async {});
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
    when(
      () =>
          source.addFavoriteFolder(any(), taskOrigin: any(named: 'taskOrigin')),
    ).thenAnswer((call) async {
      events.add('cloud.add:${call.positionalArguments[0]}');
    });
    when(
      () => local.addFavoriteFolder(any(), sourceKey: any(named: 'sourceKey')),
    ).thenAnswer((call) async {
      events.add(
        'local.add:${call.positionalArguments[0]}:${call.namedArguments[#sourceKey]}',
      );
    });
    when(
      () => source.renameFavoriteFolder(
        any(),
        any(),
        sourceKey: any(named: 'sourceKey'),
        taskOrigin: any(named: 'taskOrigin'),
      ),
    ).thenAnswer((_) async {
      events.add('cloud.rename');
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
    when(
      () => source.deleteFavoriteFolder(
        any(),
        taskOrigin: any(named: 'taskOrigin'),
      ),
    ).thenAnswer((call) async {
      events.add('cloud.delete:${call.positionalArguments[0]}');
    });
    when(
      () =>
          local.deleteFavoriteFolder(any(), sourceKey: any(named: 'sourceKey')),
    ).thenAnswer((call) async {
      events.add(
        'local.delete:${call.positionalArguments[0]}:${call.namedArguments[#sourceKey]}',
      );
    });
    controller = FavoritePageController(
      taskControl: FakeSourceTaskControl(),
      sourceService: source,
      localFavoritesRepository: local,
      localFavoritesPreferences: preferences,
    );
    controller.addListener(
      () => events.add(
        'notify:${controller.loadingFolders}:${controller.selectedFolderId}',
      ),
    );
  });

  tearDown(() {
    if (!disposed) controller.dispose();
  });

  Future<void> start({
    FavoritePageMode mode = FavoritePageMode.cloud,
    String selected = '0',
  }) async {
    savedMode = mode;
    if (mode == FavoritePageMode.cloud) {
      savedCloudId = selected;
    } else {
      savedLocalId = selected;
    }
    await controller.loadInitial(timeoutMessage: 'timeout');
    events.clear();
  }

  Future<void> transition(String kind) async {
    switch (kind) {
      case 'source':
        sourceKey = 'other';
      case 'mode':
        await controller.toggleMode(timeoutMessage: 'timeout');
      case 'invalidate':
        controller.resetForReload();
      case 'logout':
        controller.resetLoggedOut();
      case 'dispose':
        controller.dispose();
        disposed = true;
    }
    events.clear();
  }

  test(
    'unsupported cloud directories reset and persist the default selection',
    () async {
      await start(selected: 'cloud-1');
      when(() => source.supportFavoriteFolderLoad).thenReturn(false);
      await controller.reloadFolders();
      expect(controller.folders, [defaultCloudFavoriteFolder]);
      expect(controller.selectedFolderId, '0');
      expect(events, ['save:cloud:0:jm', 'notify:false:0']);
    },
  );

  test('empty cloud results retain the default directory', () async {
    await start();
    cloudFolders = [];
    await controller.reloadFolders();
    expect(controller.folders, [defaultCloudFavoriteFolder]);
    expect(events, ['notify:true:0', 'cloud.load', 'notify:false:0']);
  });

  test('missing selection falls back and persists before notifying', () async {
    await start(selected: 'cloud-1');
    cloudFolders = [defaultCloudFavoriteFolder];
    await controller.reloadFolders();
    expect(controller.selectedFolderId, '0');
    expect(events, [
      'notify:true:cloud-1',
      'cloud.load',
      'save:cloud:0:jm',
      'notify:false:0',
    ]);
  });

  test(
    'cloud directory errors finish loading before the error callback',
    () async {
      await start();
      when(
        () => source.loadFavoriteFolders(taskOrigin: any(named: 'taskOrigin')),
      ).thenAnswer(
        (_) async => const FavoriteFoldersResult.error('load failed'),
      );
      await controller.reloadFolders(
        onError: (error) {
          expect(controller.loadingFolders, isFalse);
          events.add('error:$error');
        },
      );
      expect(events, ['notify:true:0', 'notify:false:0', 'error:load failed']);
    },
  );

  test('empty local directories clear selection and comic state', () async {
    await start(mode: FavoritePageMode.local, selected: 'local-1');
    expect(controller.comics, isNotEmpty);
    localFolders = [];
    await controller.reloadFolders();
    expect(controller.selectedFolderId, '');
    expect(controller.folders, isEmpty);
    expect(controller.comics, isEmpty);
    expect(controller.hasMore, isFalse);
    expect(controller.errorMessage, isNull);
    expect(events, [
      'notify:true:local-1',
      'local.load',
      'save:local::jm',
      'notify:false:',
    ]);
  });

  test(
    'local mode initialization suppresses directory loading notifications',
    () async {
      await start();
      await controller.toggleMode(timeoutMessage: 'timeout');
      expect(controller.mode, FavoritePageMode.local);
      expect(controller.folders, localFolders);
      expect(controller.loadingFolders, isFalse);
      expect(
        events.where((event) => event.startsWith('notify:true:')),
        isEmpty,
      );
    },
  );

  for (final mode in FavoritePageMode.values) {
    test(
      'creates a $mode folder then selects the first matching name',
      () async {
        await start(
          mode: mode,
          selected: mode == FavoritePageMode.local ? 'local-1' : '0',
        );
        final added = _folder(
          'new',
          'new',
          mode == FavoritePageMode.local
              ? FavoriteFolderSource.local
              : FavoriteFolderSource.cloud,
        );
        if (mode == FavoritePageMode.local) {
          localFolders = [...localFolders, added];
        } else {
          cloudFolders = [...cloudFolders, added];
        }
        expect(
          await controller.createFolder('new', timeoutMessage: 'timeout'),
          isNull,
        );
        expect(controller.selectedFolderId, 'new');
        expect(
          events.first,
          mode == FavoritePageMode.local ? 'local.add:new:jm' : 'cloud.add:new',
        );
        expect(
          events,
          containsAllInOrder(['save:${mode.name}:new:jm', 'comics:new']),
        );
      },
    );
  }

  test(
    'create waits for selection completion and returns selection persistence errors',
    () async {
      await start();
      final pending = Completer<FavoriteComicsResult>();
      when(
        () => source.loadFavoriteComics(
          page: 1,
          folderId: 'cloud-1',
          taskOrigin: any(named: 'taskOrigin'),
        ),
      ).thenAnswer((_) => pending.future);
      var completed = false;
      final create = controller
          .createFolder('one', timeoutMessage: 'timeout')
          .then((value) {
            completed = true;
            return value;
          });
      await _settle();
      expect(completed, isFalse);
      pending.complete(FavoriteComicsResult.success(const []));
      expect(await create, isNull);
      await controller.selectFolder('0', timeoutMessage: 'timeout');
      when(
        () => preferences.saveSelectedFavoriteFolderId(
          FavoritePageMode.cloud,
          'cloud-1',
          sourceKey: 'jm',
        ),
      ).thenThrow(StateError('selection failed'));
      expect(
        await controller.createFolder('one', timeoutMessage: ''),
        contains('selection failed'),
      );
    },
  );

  test(
    'create converts fallback persistence failures to the existing error string',
    () async {
      await start(selected: 'cloud-1');
      cloudFolders = [defaultCloudFavoriteFolder];
      when(
        () => preferences.saveSelectedFavoriteFolderId(
          FavoritePageMode.cloud,
          '0',
          sourceKey: 'jm',
        ),
      ).thenThrow(StateError('save failed'));
      expect(
        await controller.createFolder('one', timeoutMessage: ''),
        contains('save failed'),
      );
      expect(events.where((event) => event.startsWith('comics:')), isEmpty);
    },
  );

  test('local rename trims the id and reloads directories', () async {
    await start(mode: FavoritePageMode.local, selected: 'local-1');
    expect(await controller.renameFolder(' local-1 ', 'renamed'), isNull);
    expect(events, [
      'local.rename:local-1:renamed:jm',
      'notify:true:local-1',
      'local.load',
      'notify:false:local-1',
    ]);
  });

  test(
    'rename ignores unsupported cloud plugins and empty local ids',
    () async {
      await start();
      await controller.renameFolder('cloud-1', 'renamed');
      expect(events, isEmpty);
      await controller.toggleMode(timeoutMessage: '');
      events.clear();
      await controller.renameFolder('  ', 'renamed');
      expect(events, isEmpty);
    },
  );

  test('cloud rename refreshes names and preserves selection', () async {
    await start(selected: 'cloud-1');
    when(() => source.supportFavoriteFolderRename).thenReturn(true);
    cloudFolders = [
      defaultCloudFavoriteFolder,
      _folder('cloud-1', 'renamed', FavoriteFolderSource.cloud),
    ];
    expect(await controller.renameFolder(' cloud-1 ', 'renamed'), isNull);
    expect(controller.folders.last.name, 'renamed');
    expect(controller.selectedFolderId, 'cloud-1');
    expect(events, [
      'cloud.rename',
      'notify:true:cloud-1',
      'cloud.load',
      'notify:false:cloud-1',
    ]);
    verify(
      () => source.renameFavoriteFolder(
        'cloud-1',
        'renamed',
        sourceKey: 'jm',
        taskOrigin: any(named: 'taskOrigin'),
      ),
    ).called(1);
  });

  test('cloud rename ignores the all folder and logged-out accounts', () async {
    await start();
    when(() => source.supportFavoriteFolderRename).thenReturn(true);
    await controller.renameFolder('0', 'renamed');
    when(() => source.isLogged).thenReturn(false);
    await controller.renameFolder('cloud-1', 'renamed');
    expect(events, isEmpty);
  });

  for (final mode in FavoritePageMode.values) {
    test(
      '$mode rename failure is returned without a directory reload',
      () async {
        await start(
          mode: mode,
          selected: mode == FavoritePageMode.local ? 'local-1' : '0',
        );
        when(() => source.supportFavoriteFolderRename).thenReturn(true);
        when(
          () => source.renameFavoriteFolder(
            any(),
            any(),
            sourceKey: any(named: 'sourceKey'),
            taskOrigin: any(named: 'taskOrigin'),
          ),
        ).thenThrow(StateError('rename failed'));
        when(
          () => local.renameFavoriteFolder(
            folderId: any(named: 'folderId'),
            name: any(named: 'name'),
            sourceKey: any(named: 'sourceKey'),
          ),
        ).thenThrow(StateError('rename failed'));
        expect(
          await controller.renameFolder('folder', 'renamed'),
          contains('rename failed'),
        );
        expect(events, isEmpty);
      },
    );
  }

  test('cloud rename reports a failed folder refresh', () async {
    await start();
    when(() => source.supportFavoriteFolderRename).thenReturn(true);
    when(
      () => source.loadFavoriteFolders(taskOrigin: any(named: 'taskOrigin')),
    ).thenAnswer(
      (_) async => const FavoriteFoldersResult.error('refresh failed'),
    );
    expect(
      await controller.renameFolder('cloud-1', 'renamed'),
      'refresh failed',
    );
    expect(controller.loadingFolders, isFalse);
  });

  for (final change in ['source', 'mode', 'dispose']) {
    test('cloud rename completion after $change does not reload', () async {
      await start();
      when(() => source.supportFavoriteFolderRename).thenReturn(true);
      final pending = Completer<void>();
      when(
        () => source.renameFavoriteFolder(
          any(),
          any(),
          sourceKey: any(named: 'sourceKey'),
          taskOrigin: any(named: 'taskOrigin'),
        ),
      ).thenAnswer((_) => pending.future);
      final rename = controller.renameFolder('cloud-1', 'renamed');
      await transition(change);
      pending.complete();
      // The page also retires the UI owner on mode changes and disposal;
      // retain its existing cancellation result as well as the no-write rule.
      expect(await rename, switch (change) {
        'source' => null,
        'dispose' => 'plugin_ui_cancelled:ownerGone',
        _ => 'plugin_ui_cancelled:superseded',
      });
      expect(events, isEmpty);
    });
  }

  test('local rename completion after disposal does not reload', () async {
    await start(mode: FavoritePageMode.local, selected: 'local-1');
    final pending = Completer<void>();
    when(
      () => local.renameFavoriteFolder(
        folderId: any(named: 'folderId'),
        name: any(named: 'name'),
        sourceKey: any(named: 'sourceKey'),
      ),
    ).thenAnswer((_) => pending.future);
    final rename = controller.renameFolder('local-1', 'renamed');
    await transition('dispose');
    pending.complete();
    expect(await rename, isNull);
    expect(events, isEmpty);
  });

  test('default cloud and empty local directories cannot be deleted', () async {
    await start();
    await controller.deleteCurrentFolder(timeoutMessage: '');
    expect(events, isEmpty);
    localFolders = [];
    await controller.toggleMode(timeoutMessage: '');
    events.clear();
    await controller.deleteCurrentFolder(timeoutMessage: '');
    expect(events, isEmpty);
  });

  test(
    'local deletion persists the fallback before completing selection',
    () async {
      await start(mode: FavoritePageMode.local, selected: 'local-1');
      localFolders = [
        _folder('local-2', 'remaining', FavoriteFolderSource.local),
      ];
      expect(
        await controller.deleteCurrentFolder(timeoutMessage: 'timeout'),
        isNull,
      );
      expect(controller.selectedFolderId, 'local-2');
      expect(events, [
        'local.delete:local-1:jm',
        'save:local::jm',
        'notify:true:',
        'local.load',
        'save:local:local-2:jm',
        'notify:false:local-2',
      ]);
    },
  );

  for (final action in ['create', 'rename', 'delete']) {
    test(
      'local $action completion cannot mutate a newly selected source',
      () async {
        await start(mode: FavoritePageMode.local, selected: 'local-1');
        final previous = controller.folders;
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
          'create' => controller.createFolder('new', timeoutMessage: ''),
          'rename' => controller.renameFolder('local-1', 'new'),
          _ => controller.deleteCurrentFolder(timeoutMessage: ''),
        };
        await transition('source');
        pending.complete();
        expect(await mutation, isNull);
        expect(events, isEmpty);
        expect(controller.folders, same(previous));
        expect(controller.selectedFolderId, 'local-1');
      },
    );
  }

  test(
    'cloud deletion loads the fallback before starting a nonblocking directory refresh',
    () async {
      await start(selected: 'cloud-1');
      final pending = Completer<FavoriteFoldersResult>();
      when(
        () => source.loadFavoriteFolders(taskOrigin: any(named: 'taskOrigin')),
      ).thenAnswer((_) {
        events.add('cloud.load');
        return pending.future;
      });
      expect(
        await controller.deleteCurrentFolder(timeoutMessage: 'timeout'),
        isNull,
      );
      expect(controller.selectedFolderId, '0');
      expect(controller.loadingFolders, isTrue);
      expect(
        events,
        containsAllInOrder([
          'cloud.delete:cloud-1',
          'save:cloud:0:jm',
          'comics:0',
          'cloud.load',
        ]),
      );
      pending.complete(_result([defaultCloudFavoriteFolder]));
      await _settle();
      expect(controller.loadingFolders, isFalse);
      expect(events.last, 'notify:false:0');
    },
  );

  test('delete failure does not persist a fallback selection', () async {
    await start(selected: 'cloud-1');
    when(
      () => source.deleteFavoriteFolder(
        'cloud-1',
        taskOrigin: any(named: 'taskOrigin'),
      ),
    ).thenThrow(StateError('delete failed'));
    expect(
      await controller.deleteCurrentFolder(timeoutMessage: ''),
      contains('delete failed'),
    );
    expect(controller.selectedFolderId, 'cloud-1');
    expect(events, isEmpty);
  });

  test('failed cloud deletion leaves a pending folder refresh valid', () async {
    await start(selected: 'cloud-1');
    final pending = Completer<FavoriteFoldersResult>();
    when(
      () => source.loadFavoriteFolders(taskOrigin: any(named: 'taskOrigin')),
    ).thenAnswer((_) => pending.future);
    final reload = controller.reloadFolders();
    when(
      () => source.deleteFavoriteFolder(
        'cloud-1',
        taskOrigin: any(named: 'taskOrigin'),
      ),
    ).thenThrow(StateError('delete failed'));
    expect(
      await controller.deleteCurrentFolder(timeoutMessage: ''),
      contains('delete failed'),
    );
    final refreshed = [
      defaultCloudFavoriteFolder,
      _folder('cloud-1', 'renamed', FavoriteFolderSource.cloud),
    ];
    pending.complete(_result(refreshed));
    await reload;
    expect(controller.folders, same(refreshed));
    expect(controller.selectedFolderId, 'cloud-1');
    expect(controller.loadingFolders, isFalse);
  });

  for (final change in ['source', 'mode', 'invalidate', 'logout', 'dispose']) {
    test('cloud deletion ignores a stale completion after $change', () async {
      await start(selected: 'cloud-1');
      final pending = Completer<void>();
      when(
        () => source.deleteFavoriteFolder(
          'cloud-1',
          taskOrigin: any(named: 'taskOrigin'),
        ),
      ).thenAnswer((_) => pending.future);
      final deletion = controller.deleteCurrentFolder(
        timeoutMessage: 'timeout',
      );
      await transition(change);
      final expected = controller.folders;
      pending.complete();
      expect(await deletion, switch (change) {
        'source' => null,
        'dispose' => 'plugin_ui_cancelled:ownerGone',
        _ => 'plugin_ui_cancelled:superseded',
      });
      expect(controller.folders, same(expected));
      expect(events, isEmpty);
    });
    test('late directory results are discarded after $change', () async {
      await start();
      final pending = Completer<FavoriteFoldersResult>();
      when(
        () => source.loadFavoriteFolders(taskOrigin: any(named: 'taskOrigin')),
      ).thenAnswer((_) => pending.future);
      final reload = controller.reloadFolders();
      await transition(change);
      final expected = controller.folders;
      pending.complete(
        _result([_folder('late', 'late', FavoriteFolderSource.cloud)]),
      );
      await reload;
      expect(controller.folders, same(expected));
      expect(events, isEmpty);
    });
  }
}
