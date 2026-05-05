import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/local_favorites_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocalFavoritesService selected favorite folder persistence', () {
    late LocalFavoritesService service;

    setUp(() {
      SharedPreferences.setMockInitialValues(const {});
      service = LocalFavoritesService.instance;
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

  group('LocalFavoritesService source-scoped entries', () {
    late LocalFavoritesService service;

    setUp(() {
      SharedPreferences.setMockInitialValues(const {});
      service = LocalFavoritesService.instance;
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

    test(
      'legacy entries without source key can be read by current source',
      () async {
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
      },
    );
  });
}
