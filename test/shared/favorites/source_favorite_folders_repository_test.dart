import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/local_favorites/local_favorites_contracts.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/shared/favorites/source_favorite_folders_repository.dart';
import 'package:mocktail/mocktail.dart';

class _Source extends Mock implements SourceFavoriteFoldersGateway {}

class _Local extends Mock implements LocalFavoritesRepository {}

void main() {
  for (final sourceKey in ['', ' a ']) {
    test('folder operations retain the bound source ($sourceKey)', () async {
      final source = _Source();
      var activeSource = 'a';
      when(() => source.activeSourceKey).thenAnswer((_) => activeSource);
      when(() => source.isLoggedForSource('a')).thenReturn(true);
      when(
        () => source.supportFavoriteFolderLoadForSource('a'),
      ).thenReturn(true);
      when(
        () => source.supportFavoriteFolderAddForSource('a'),
      ).thenReturn(true);
      when(
        () => source.supportFavoriteFolderDeleteForSource('a'),
      ).thenReturn(true);
      when(() => source.supportFavoriteToggleForSource('a')).thenReturn(true);
      when(
        () => source.favoriteSingleFolderForSingleComicForSource('a'),
      ).thenReturn(false);
      const result = FavoriteFoldersResult.success(
        folders: [],
        favoritedFolderIds: {},
      );
      when(
        () => source.loadFavoriteFolders(comicId: 'comic', sourceKey: 'a'),
      ).thenAnswer((_) async => result);
      when(
        () => source.addFavoriteFolder('new', sourceKey: 'a'),
      ).thenAnswer((_) async {});
      when(
        () => source.deleteFavoriteFolder('folder', sourceKey: 'a'),
      ).thenAnswer((_) async {});
      when(
        () => source.toggleFavorite(
          comicId: 'comic',
          isAdding: true,
          folderId: 'folder',
          sourceKey: 'a',
        ),
      ).thenAnswer((_) async {});

      final repository = SourceFavoriteFoldersRepository(
        source: source,
        local: _Local(),
        sourceKey: sourceKey,
      );
      activeSource = 'b';

      expect(repository.isLogged, isTrue);
      expect(repository.supportFavoriteFolderLoad, isTrue);
      expect(repository.supportFavoriteFolderAdd, isTrue);
      expect(repository.supportFavoriteFolderDelete, isTrue);
      expect(repository.supportFavoriteToggle, isTrue);
      expect(repository.favoriteSingleFolderForSingleComic, isFalse);
      expect(
        await repository.loadCloudFavoriteFolders(comicId: 'comic'),
        same(result),
      );
      await repository.addCloudFavoriteFolder('new');
      await repository.deleteCloudFavoriteFolder('folder');
      await repository.toggleCloudFavorite(
        comicId: 'comic',
        isAdding: true,
        folderId: 'folder',
      );
      verify(
        () => source.loadFavoriteFolders(comicId: 'comic', sourceKey: 'a'),
      ).called(1);
      verify(() => source.addFavoriteFolder('new', sourceKey: 'a')).called(1);
      verify(
        () => source.deleteFavoriteFolder('folder', sourceKey: 'a'),
      ).called(1);
      verify(
        () => source.toggleFavorite(
          comicId: 'comic',
          isAdding: true,
          folderId: 'folder',
          sourceKey: 'a',
        ),
      ).called(1);
    });
  }
}
