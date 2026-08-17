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

  test('adds the all folder and filters unknown favorited ids', () {
    final data = parser.parseFolders({
      'folders': {'folder-a': 'Folder A', 'folder-b': null},
      'favorited': ['folder-a', 'missing', '', null],
    });

    expect(data.folders.map((folder) => (folder.id, folder.name)), [
      ('0', '__favorite_all__'),
      ('folder-a', 'Folder A'),
      ('folder-b', 'folder-b'),
    ]);
    expect(data.favoritedFolderIds, {'folder-a'});

    final withAll = parser.parseFolders({
      'folders': {'0': 'Everything'},
      'favorited': ['0'],
    });
    expect(withAll.folders, hasLength(1));
    expect(withAll.folders.single.name, 'Everything');
    expect(withAll.favoritedFolderIds, {'0'});
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
