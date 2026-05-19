import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/app/service_locator.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/local_favorites_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../support/test_service_locator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    await ensureTestServiceLocator();
  });

  group('LocalFavoritesService selected favorite folder persistence', () {
    late LocalFavoritesService service;

    setUp(() {
      SharedPreferences.setMockInitialValues(const {});
      service = sl<LocalFavoritesService>();
    });

    test('uses mode-specific defaults when no folder was saved', () async {
      expect(
        await service.loadSelectedFavoriteFolderId(FavoritePageMode.cloud),
        '0',
      );
      expect(
        await service.loadSelectedFavoriteFolderId(FavoritePageMode.local),
        isEmpty,
      );
    });

    test(
      'saves and restores cloud and local folder ids independently',
      () async {
        await service.saveSelectedFavoriteFolderId(
          FavoritePageMode.cloud,
          ' cloud-b ',
        );
        await service.saveSelectedFavoriteFolderId(
          FavoritePageMode.local,
          ' local-b ',
        );

        expect(
          await service.loadSelectedFavoriteFolderId(FavoritePageMode.cloud),
          'cloud-b',
        );
        expect(
          await service.loadSelectedFavoriteFolderId(FavoritePageMode.local),
          'local-b',
        );
      },
    );

    test('normalizes empty cloud ids and clears empty local ids', () async {
      await service.saveSelectedFavoriteFolderId(FavoritePageMode.cloud, '');
      await service.saveSelectedFavoriteFolderId(
        FavoritePageMode.local,
        'local-b',
      );
      await service.saveSelectedFavoriteFolderId(FavoritePageMode.local, '');

      expect(
        await service.loadSelectedFavoriteFolderId(FavoritePageMode.cloud),
        '0',
      );
      expect(
        await service.loadSelectedFavoriteFolderId(FavoritePageMode.local),
        isEmpty,
      );
    });
  });

  group('LocalFavoritesService favorite sort order', () {
    late LocalFavoritesService service;

    setUp(() {
      SharedPreferences.setMockInitialValues(const {});
      service = sl<LocalFavoritesService>();
    });

    test('preserves CopyManga sort orders', () async {
      await service.saveSortOrder('-datetime_updated');
      expect(await service.loadSortOrder(), '-datetime_updated');

      await service.saveSortOrder('-datetime_modifier');
      expect(await service.loadSortOrder(), '-datetime_modifier');

      await service.saveSortOrder('-datetime_browse');
      expect(await service.loadSortOrder(), '-datetime_browse');
    });

    test('preserves Picacg favorite sort orders', () async {
      await service.saveSortOrder('dd');
      expect(await service.loadSortOrder(), 'dd');

      await service.saveSortOrder('da');
      expect(await service.loadSortOrder(), 'da');
    });

    test('sorts CopyManga local favorites by update time', () async {
      await service.addFavoriteFolder('Copy', sourceKey: 'copy_manga');
      final folder = (await service.loadFavoriteFolders(
        sourceKey: 'copy_manga',
      )).folders.single;

      await service.toggleFavorite(
        details: const ComicDetailsData(
          id: 'newer',
          sourceKey: 'copy_manga',
          title: 'Newer',
          subTitle: '',
          cover: '',
          description: '',
          updateTime: '2026-05-16',
          likesCount: '',
          chapters: {},
          tags: {},
          recommend: [],
          isFavorite: false,
          subId: '',
        ),
        isAdding: true,
        folderId: folder.id,
      );
      await service.toggleFavorite(
        details: const ComicDetailsData(
          id: 'older',
          sourceKey: 'copy_manga',
          title: 'Older',
          subTitle: '',
          cover: '',
          description: '',
          updateTime: '2026-05-15',
          likesCount: '',
          chapters: {},
          tags: {},
          recommend: [],
          isFavorite: false,
          subId: '',
        ),
        isAdding: true,
        folderId: folder.id,
      );

      final comics = await service.loadFavoriteComics(
        page: 1,
        folderId: folder.id,
        sortOrder: '-datetime_updated',
        sourceKey: 'copy_manga',
      );

      expect(comics.comics.map((comic) => comic.id), <String>[
        'newer',
        'older',
      ]);
    });
  });

  group('LocalFavoritesService source-scoped entries', () {
    late LocalFavoritesService service;

    setUp(() {
      SharedPreferences.setMockInitialValues(const {});
      service = sl<LocalFavoritesService>();
    });

    test('keeps the same comic id separate across source keys', () async {
      await service.addFavoriteFolder('JM', sourceKey: 'jm');
      await service.addFavoriteFolder('Other', sourceKey: 'other');

      final jmFolders = await service.loadFavoriteFolders(sourceKey: 'jm');
      final otherFolders = await service.loadFavoriteFolders(
        sourceKey: 'other',
      );

      await service.toggleFavorite(
        details: const ComicDetailsData(
          id: '123',
          sourceKey: 'jm',
          title: 'JM title',
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
        ),
        isAdding: true,
        folderId: jmFolders.folders.single.id,
      );
      await service.toggleFavorite(
        details: const ComicDetailsData(
          id: '123',
          sourceKey: 'other',
          title: 'Other title',
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
        ),
        isAdding: true,
        folderId: otherFolders.folders.single.id,
      );

      final jmComics = await service.loadFavoriteComics(
        page: 1,
        folderId: jmFolders.folders.single.id,
        sourceKey: 'jm',
      );
      final otherComics = await service.loadFavoriteComics(
        page: 1,
        folderId: otherFolders.folders.single.id,
        sourceKey: 'other',
      );

      expect(jmComics.comics.single.title, 'JM title');
      expect(jmComics.comics.single.sourceKey, 'jm');
      expect(otherComics.comics.single.title, 'Other title');
      expect(otherComics.comics.single.sourceKey, 'other');
    });

    test('legacy entries without source key belong to the JM source', () async {
      SharedPreferences.setMockInitialValues({
        'local_favorite_folders_v1': '[{"id":"folder","name":"Legacy"}]',
        'local_favorite_entries_v1':
            '[{"comicId":"123","title":"Legacy","folderIds":["folder"]}]',
      });

      final folders = await service.loadFavoriteFolders(sourceKey: 'jm');
      final comics = await service.loadFavoriteComics(
        page: 1,
        folderId: folders.folders.single.id,
        sourceKey: 'jm',
      );

      expect(comics.comics.single.id, '123');
      expect(comics.comics.single.title, 'Legacy');
      expect(comics.comics.single.sourceKey, 'jm');

      final copyFolders = await service.loadFavoriteFolders(
        sourceKey: 'copy_manga',
      );
      final copyComics = await service.loadFavoriteComics(
        page: 1,
        folderId: 'folder',
        sourceKey: 'copy_manga',
      );

      expect(copyFolders.folders, isEmpty);
      expect(copyComics.comics, isEmpty);
    });

    test(
      'legacy local folders can be renamed and deleted from the JM source only',
      () async {
        SharedPreferences.setMockInitialValues({
          'local_favorite_folders_v1': '[{"id":"folder","name":"Legacy"}]',
          'local_favorite_entries_v1':
              '[{"comicId":"123","title":"Legacy","folderIds":["folder"]}]',
        });

        await service.renameFavoriteFolder(
          folderId: 'folder',
          name: 'JM Legacy',
          sourceKey: 'jm',
        );
        final jmFolders = await service.loadFavoriteFolders(sourceKey: 'jm');
        expect(jmFolders.folders.single.name, 'JM Legacy');

        expect(
          service.renameFavoriteFolder(
            folderId: 'folder',
            name: 'Copy Legacy',
            sourceKey: 'copy_manga',
          ),
          throwsException,
        );

        await service.deleteFavoriteFolder('folder', sourceKey: 'jm');
        final foldersAfterDelete = await service.loadFavoriteFolders(
          sourceKey: 'jm',
        );
        final comicsAfterDelete = await service.loadFavoriteComics(
          page: 1,
          folderId: 'folder',
          sourceKey: 'jm',
        );

        expect(foldersAfterDelete.folders, isEmpty);
        expect(comicsAfterDelete.comics, isEmpty);
      },
    );
  });
}
