import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/source/favorites/source_favorites_response_parser.dart';

void main() {
  final parsedSourceKeys = <String>[];
  late SourceFavoritesResponseParser parser;

  setUp(() {
    parsedSourceKeys.clear();
    parser = SourceFavoritesResponseParser((comics, {sourceKey = ''}) {
      parsedSourceKeys.add(sourceKey);
      return comics.map((raw) {
        final map = Map<String, dynamic>.from(raw as Map);
        return ExploreComic(
          id: map['id']?.toString() ?? '',
          title: map['title']?.toString() ?? '',
          subTitle: '',
          cover: '',
          sourceKey: sourceKey,
        );
      }).toList();
    });
  });

  test('normalizes folder ids and merges comics by newest occurrence', () {
    const older = ExploreComic(
      id: 'same',
      title: 'Older',
      subTitle: '',
      cover: '',
    );
    const newer = ExploreComic(
      id: 'same',
      title: 'Newer',
      subTitle: '',
      cover: '',
    );
    const other = ExploreComic(
      id: 'other',
      title: 'Other',
      subTitle: '',
      cover: '',
    );

    expect(SourceFavoritesResponseParser.normalizeFolderId('  '), '0');
    expect(
      SourceFavoritesResponseParser.normalizeFolderId(' folder '),
      'folder',
    );
    final merged = SourceFavoritesResponseParser.mergeComics([
      older,
      newer,
      other,
    ]);
    expect(merged.map((comic) => comic.id), ['same', 'other']);
    expect(merged.first.title, 'Newer');
  });

  test('parses comic pages and normalizes max-page representations', () {
    final page = parser.parseComicsPage({
      'comics': [
        {'id': 'comic', 'title': 'Title'},
      ],
      'maxPage': '12',
    }, sourceKey: 'copy_manga');

    expect(page.comics.single.id, 'comic');
    expect(page.comics.single.sourceKey, 'copy_manga');
    expect(page.maxPage, 12);
    expect(parsedSourceKeys, ['copy_manga']);
    expect(SourceFavoritesResponseParser.parseMaxPage(4.9), 4);
    expect(SourceFavoritesResponseParser.parseMaxPage('invalid'), isNull);
    expect(parser.parseComicsPage(null).comics, isEmpty);
  });

  test('preserves plugin folders and filters unknown favorited ids', () {
    final data = parser.parseFolders({
      'folders': {'folder-a': 'Folder A', 'folder-b': null},
      'favorited': ['folder-a', 'missing', '', null],
    });

    expect(data.folders.map((folder) => (folder.id, folder.name)), [
      ('folder-a', 'Folder A'),
      ('folder-b', 'folder-b'),
    ]);
    expect(data.favoritedFolderIds, {'folder-a'});
  });

  test('a single named shelf does not get an extra all folder', () {
    final data = parser.parseFolders({
      'folders': {'shelf': '書架'},
      'favorited': ['shelf', '0'],
    });

    expect(data.folders.single.id, 'shelf');
    expect(data.folders.single.name, '書架');
    expect(data.favoritedFolderIds, {'shelf'});
  });

  test('preserves an explicitly declared legacy all folder', () {
    final withAll = parser.parseFolders({
      'folders': {'0': 'Everything', 'shelf': 'Shelf'},
      'favorited': ['0'],
    });
    expect(withAll.folders.map((folder) => folder.id), ['0', 'shelf']);
    expect(withAll.folders.first.name, 'Everything');
    expect(withAll.favoritedFolderIds, {'0'});
  });

  test('supplies a default only when no usable folders were returned', () {
    for (final response in <Map<String, dynamic>>[
      {},
      {'folders': <String, String>{}},
      {
        'folders': {'': 'Invalid'},
      },
    ]) {
      final data = parser.parseFolders(response);
      expect(data.folders.single.id, '0');
      expect(data.folders.single.name, '__favorite_all__');
      expect(data.favoritedFolderIds, isEmpty);
    }
  });

  test('extracts non-empty concrete folder ids for aggregate loading', () {
    expect(
      parser.extractFolderIds({
        'folders': {'0': 'All', ' first ': 'First', '': 'Empty', 2: 'Second'},
      }),
      ['first', '2'],
    );
    expect(parser.extractFolderIds(null), isEmpty);
    expect(parser.extractFolderIds({'folders': const []}), isEmpty);
  });
}
