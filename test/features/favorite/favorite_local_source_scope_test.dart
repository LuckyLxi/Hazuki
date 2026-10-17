import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/favorite/state/favorite_page_controller.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/local_favorites/local_favorites_preferences_store.dart';
import 'package:hazuki/services/local_favorites_service.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/services/storage/hazuki_database.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Source extends Mock implements SourceFavoriteGateway {}

ComicDetailsData _comic(String sourceKey) => ComicDetailsData(
  id: 'same-id',
  sourceKey: sourceKey,
  title: '$sourceKey comic',
  subTitle: '',
  cover: '',
  description: '',
  updateTime: '',
  likesCount: '',
  chapters: const {},
  tags: const {},
  recommend: const [],
  isFavorite: false,
  subId: '',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'local favorites stay isolated when loading, refreshing and switching sources',
    () async {
      SharedPreferences.setMockInitialValues(const {});
      final database = HazukiDatabase.memory();
      addTearDown(database.close);
      final preferences = SharedPreferencesLocalFavoritesPreferencesStore();
      final local = LocalFavoritesService(
        database: database,
        preferences: preferences,
      );
      addTearDown(local.dispose);
      final folderIds = <String, String>{};
      for (final key in ['jm', 'other']) {
        await local.addFavoriteFolder('$key folder', sourceKey: key);
        final folders = await local.loadFavoriteFolders(sourceKey: key);
        folderIds[key] = folders.folders.single.id;
        await local.toggleFavorite(
          details: _comic(key),
          isAdding: true,
          folderId: folderIds[key]!,
        );
        await preferences.saveFavoritePageMode(
          FavoritePageMode.local,
          sourceKey: key,
        );
      }

      var activeSource = 'jm';
      late VoidCallback sourceChanged;
      final source = _Source();
      when(() => source.activeSourceKey).thenAnswer((_) => activeSource);
      when(() => source.isLogged).thenReturn(false);
      when(() => source.favoriteSortOrder).thenReturn('');
      when(
        () => source.cloudFavoritesChangedStream,
      ).thenAnswer((_) => const Stream<void>.empty());
      when(() => source.addListener(any())).thenAnswer((call) {
        sourceChanged = call.positionalArguments.single as VoidCallback;
      });
      final controller = FavoritePageController(
        sourceService: source,
        localFavoritesRepository: local,
        localFavoritesPreferences: preferences,
      );
      addTearDown(controller.dispose);

      void expectSource(String key) {
        expect(controller.folders.map((folder) => folder.id), [folderIds[key]]);
        expect(controller.selectedFolderId, folderIds[key]);
        expect(controller.comics.single.sourceKey, key);
        expect(controller.comics.single.title, '$key comic');
      }

      await controller.loadInitial(timeoutMessage: 'timeout');
      expectSource('jm');
      await controller.refresh(timeoutMessage: 'timeout');
      expectSource('jm');

      for (final key in ['other', 'jm']) {
        final loaded = Completer<void>();
        void onLoaded() {
          if (!controller.initialLoading && !loaded.isCompleted) {
            loaded.complete();
          }
        }

        controller.addListener(onLoaded);
        activeSource = key;
        sourceChanged();
        // Do not leave the previous source's data interactive while preferences load.
        expect(controller.folders, isEmpty);
        expect(controller.comics, isEmpty);
        await loaded.future.timeout(const Duration(seconds: 5));
        controller.removeListener(onLoaded);
        expectSource(key);
      }
      expect((await local.loadFavoriteFolders()).folders, hasLength(2));
    },
  );
}
