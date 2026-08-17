import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/source/favorites/source_favorites_script_factory.dart';

void main() {
  const factory = SourceFavoritesScriptFactory();

  test('distinguishes null aggregate folders from string folder ids', () {
    expect(
      factory.loadComics(page: 1, folderId: null),
      'this.__hazuki_source.favorites.loadComics(1, null)',
    );
    expect(
      factory.loadComics(page: 2, folderId: '0'),
      'this.__hazuki_source.favorites.loadComics(2, "0")',
    );
    expect(
      factory.loadNext(cursor: null, folderId: 'folder'),
      'this.__hazuki_source.favorites.loadNext(null, "folder")',
    );
  });

  test('safely encodes folder loading and mutation arguments', () {
    expect(
      factory.loadFolders(null),
      'this.__hazuki_source.favorites.loadFolders(null)',
    );
    expect(factory.loadFolders('comic"id'), contains(r'comic\"id'));
    expect(factory.addFolder('line\nbreak'), contains(r'line\nbreak'));
    expect(factory.deleteFolder("folder'id"), contains("folder'id"));
  });

  test('encodes toggle state and nullable favorite id', () {
    expect(
      factory.toggleFavorite(
        comicId: 'comic',
        folderId: 'folder',
        isAdding: true,
        favoriteId: null,
      ),
      'this.__hazuki_source.favorites.addOrDelFavorite('
      '"comic", "folder", true, null)',
    );
    expect(
      factory.toggleFavorite(
        comicId: 'comic"id',
        folderId: 'folder\\id',
        isAdding: false,
        favoriteId: 'favorite\nvalue',
      ),
      allOf(
        contains(r'comic\"id'),
        contains(r'folder\\id'),
        contains('false'),
        contains(r'favorite\nvalue'),
      ),
    );
  });
}
