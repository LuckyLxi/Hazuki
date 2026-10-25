import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/favorite/state/favorite_page_controller.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/local_favorites/local_favorites_contracts.dart';
import 'package:hazuki/services/local_favorites/local_favorites_preferences_store.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fake_source_task_control.dart';

class _Source extends Mock implements SourceFavoriteGateway {}

class _Local extends Mock implements LocalFavoritesRepository {}

class _Preferences extends Mock implements LocalFavoritesPreferencesStore {}

void main() {
  setUpAll(() => registerFallbackValue(FavoritePageMode.cloud));
  late _Source source;
  late _Local local;
  late _Preferences preferences;
  late FavoritePageController controller;
  late List<String> events;
  late String cloudOrder;
  var disposed = false;

  Future<void> initialize(FavoritePageMode mode) async {
    source = _Source();
    local = _Local();
    preferences = _Preferences();
    events = [];
    cloudOrder = 'mr';
    disposed = false;
    when(() => source.activeSourceKey).thenReturn('jm');
    when(
      () => source.cloudFavoritesChangedStream,
    ).thenAnswer((_) => const Stream.empty());
    when(() => source.favoriteSortOrder).thenAnswer((_) => cloudOrder);
    when(() => source.favoriteSortOrders).thenReturn(['mr', 'mp']);
    when(() => source.isLogged).thenReturn(true);
    when(() => source.supportFavoriteSortOrder).thenReturn(true);
    when(() => source.supportFavoriteFolderAdd).thenReturn(true);
    when(() => source.supportFavoriteFolderLoad).thenReturn(true);
    when(() => source.ensureInitialized()).thenAnswer((_) async {});
    when(() => source.setFavoriteSortOrder(any())).thenAnswer((call) async {
      cloudOrder = call.positionalArguments.single as String;
      events.add('save:$cloudOrder');
    });
    when(
      () => preferences.loadFavoritePageMode(sourceKey: 'jm'),
    ).thenAnswer((_) async => mode);
    for (final value in FavoritePageMode.values) {
      when(
        () => preferences.loadSelectedFavoriteFolderId(value, sourceKey: 'jm'),
      ).thenAnswer(
        (_) async => value == FavoritePageMode.local ? 'local' : '0',
      );
    }
    when(
      () => preferences.loadSortOrder(),
    ).thenAnswer((_) async => 'savedNewest');
    when(() => preferences.saveSortOrder(any())).thenAnswer((call) async {
      events.add('save:${call.positionalArguments.single}');
    });
    when(
      () => source.loadFavoriteFolders(taskOrigin: any(named: 'taskOrigin')),
    ).thenAnswer(
      (_) async => const FavoriteFoldersResult.success(
        folders: [
          FavoriteFolder(
            id: '0',
            name: 'all',
            source: FavoriteFolderSource.cloud,
          ),
        ],
        favoritedFolderIds: {},
      ),
    );
    when(() => local.loadFavoriteFolders(sourceKey: 'jm')).thenAnswer(
      (_) async => const FavoriteFoldersResult.success(
        folders: [
          FavoriteFolder(
            id: 'local',
            name: 'local',
            source: FavoriteFolderSource.local,
          ),
        ],
        favoritedFolderIds: {},
      ),
    );
    when(
      () => source.loadFavoriteComics(
        page: 1,
        folderId: '0',
        taskOrigin: any(named: 'taskOrigin'),
      ),
    ).thenAnswer((_) async {
      events.add('load:$cloudOrder');
      return const FavoriteComicsResult.success([]);
    });
    when(
      () => local.loadFavoriteComics(
        page: 1,
        folderId: 'local',
        sortOrder: any(named: 'sortOrder'),
        sourceKey: 'jm',
      ),
    ).thenAnswer((call) async {
      events.add('load:${call.namedArguments[#sortOrder]}');
      return const FavoriteComicsResult.success([]);
    });
    controller = FavoritePageController(
      taskControl: FakeSourceTaskControl(),
      sourceService: source,
      localFavoritesRepository: local,
      localFavoritesPreferences: preferences,
      presentationFor: (_) => {
        'favoriteOrderAliases': {'old': 'mp'},
        'favoriteDefaultOrder': 'mr',
      },
    );
    await controller.loadInitial(timeoutMessage: 'timeout');
    events.clear();
  }

  tearDown(() {
    if (!disposed) controller.dispose();
  });

  for (final mode in FavoritePageMode.values) {
    final target = mode == FavoritePageMode.local ? 'readNewest' : 'mp';
    test('$mode normalizes and persists sorting before reloading', () async {
      await initialize(mode);
      expect(
        await controller.changeSortOrder(
          mode == FavoritePageMode.local ? ' readNewest ' : ' old ',
          timeoutMessage: 'timeout',
        ),
        isNull,
      );
      expect(events, ['save:$target', 'load:$target']);
      expect(controller.appBarActionsState.currentSortOrder, target);
    });
    test('$mode repeated sort does not persist or reload', () async {
      await initialize(mode);
      expect(
        await controller.changeSortOrder(
          ' ${controller.appBarActionsState.currentSortOrder} ',
          timeoutMessage: '',
        ),
        isNull,
      );
      expect(events, isEmpty);
    });
    test('$mode completion after disposal does not update or reload', () async {
      await initialize(mode);
      final original = controller.appBarActionsState.currentSortOrder;
      final pending = Completer<void>();
      if (mode == FavoritePageMode.local) {
        when(
          () => preferences.saveSortOrder(target),
        ).thenAnswer((_) => pending.future);
      } else {
        when(
          () => source.setFavoriteSortOrder(target),
        ).thenAnswer((_) => pending.future);
      }
      final result = controller.changeSortOrder(
        target,
        timeoutMessage: 'timeout',
      );
      controller.dispose();
      disposed = true;
      pending.complete();
      // Cloud writes also lose their UI owner when the controller is disposed.
      expect(
        await result,
        mode == FavoritePageMode.local ? isNull : contains('ownerGone'),
      );
      expect(controller.appBarActionsState.currentSortOrder, original);
      expect(events, isEmpty);
    });
    test('$mode persistence failure keeps the selected order', () async {
      await initialize(mode);
      final original = controller.appBarActionsState.currentSortOrder;
      if (mode == FavoritePageMode.local) {
        when(
          () => preferences.saveSortOrder(target),
        ).thenThrow(StateError('save failed'));
      } else {
        when(
          () => source.setFavoriteSortOrder(target),
        ).thenThrow(StateError('save failed'));
      }
      expect(
        await controller.changeSortOrder(target, timeoutMessage: ''),
        contains('save failed'),
      );
      expect(controller.appBarActionsState.currentSortOrder, original);
      expect(events, isEmpty);
    });
  }

  test('local list error is returned after persisting sorting', () async {
    await initialize(FavoritePageMode.local);
    when(
      () => local.loadFavoriteComics(
        page: 1,
        folderId: 'local',
        sortOrder: 'readNewest',
        sourceKey: 'jm',
      ),
    ).thenAnswer((_) async => const FavoriteComicsResult.error('list failed'));
    expect(
      await controller.changeSortOrder('readNewest', timeoutMessage: ''),
      'list failed',
    );
    expect(controller.appBarActionsState.currentSortOrder, 'readNewest');
    expect(controller.errorMessage, 'list failed');
  });

  test(
    'cloud reload exception preserves persisted sorting and returns error',
    () async {
      await initialize(FavoritePageMode.cloud);
      when(
        () => source.loadFavoriteComics(
          page: 1,
          folderId: '0',
          taskOrigin: any(named: 'taskOrigin'),
        ),
      ).thenThrow(StateError('reload failed'));
      expect(
        await controller.changeSortOrder('mp', timeoutMessage: ''),
        contains('reload failed'),
      );
      expect(controller.appBarActionsState.currentSortOrder, 'mp');
      expect(events, ['save:mp']);
    },
  );

  test('cloud folder error reaches the caller during sorting reload', () async {
    await initialize(FavoritePageMode.cloud);
    when(
      () => source.loadFavoriteFolders(taskOrigin: any(named: 'taskOrigin')),
    ).thenAnswer(
      (_) async => const FavoriteFoldersResult.error('folders failed'),
    );
    final errors = <String>[];
    expect(
      await controller.changeSortOrder(
        'mp',
        timeoutMessage: 'timeout',
        onFolderLoadError: errors.add,
      ),
      isNull,
    );
    expect(errors, ['folders failed']);
    expect(events, ['save:mp', 'load:mp']);
  });
}
