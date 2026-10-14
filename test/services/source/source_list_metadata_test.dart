import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/local_favorites_service.dart';
import 'package:hazuki/services/read_history_service.dart';
import 'package:hazuki/services/storage/hazuki_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _presentation(String key) => key == 'custom_tags'
    ? {
        'listTagGroups': ['Genre'],
      }
    : const {};

ComicDetailsData _details(String id, {String updated = ''}) => ComicDetailsData(
  id: id,
  sourceKey: 'custom_tags',
  title: id,
  subTitle: '',
  cover: '',
  description: '',
  updateTime: updated,
  likesCount: '',
  chapters: {},
  tags: {
    'Genre': [' action ', 'action'],
    'Author': ['ignored'],
  },
  recommend: [],
  isFavorite: false,
  subId: '',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late HazukiDatabase database;
  late LocalFavoritesService favorites;
  late ReadHistoryService history;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    database = HazukiDatabase.memory();
    favorites = LocalFavoritesService(
      database: database,
      presentationFor: _presentation,
    );
    history = ReadHistoryService(
      database: database,
      presentationFor: _presentation,
    );
  });
  tearDown(() async {
    favorites.dispose();
    history.dispose();
    await database.close();
  });

  test(
    'saved favorites and history extract groups from arbitrary plugins',
    () async {
      await favorites.addFavoriteFolder('Folder', sourceKey: 'custom_tags');
      final folder = (await favorites.loadFavoriteFolders(
        sourceKey: 'custom_tags',
      )).folders.single;
      final details = _details('comic');
      await favorites.toggleFavorite(
        details: details,
        isAdding: true,
        folderId: folder.id,
      );
      final saved = await favorites.loadFavoriteComics(
        page: 1,
        folderId: folder.id,
        sourceKey: 'custom_tags',
      );
      expect(saved.comics.single.tags, ['action']);
      // The source identity can come from details rather than the original list item.
      await history.recordHistory(
        comic: ExploreComic(id: 'comic', title: '', subTitle: '', cover: ''),
        details: details,
      );
      expect(
        (await history.loadHistory(sourceKey: 'custom_tags')).single.tags,
        ['action'],
      );
    },
  );

  test(
    'missing declarations do not erase previously saved record tags',
    () async {
      await favorites.addFavoriteFolder('Folder', sourceKey: 'custom_tags');
      final folder = (await favorites.loadFavoriteFolders(
        sourceKey: 'custom_tags',
      )).folders.single;
      final details = _details('comic');
      final comic = ExploreComic(
        id: 'comic',
        sourceKey: 'custom_tags',
        title: '',
        subTitle: '',
        cover: '',
      );
      await favorites.toggleFavorite(
        details: details,
        isAdding: true,
        folderId: folder.id,
      );
      await history.recordHistory(comic: comic, details: details);
      final unconfiguredFavorites = LocalFavoritesService(database: database);
      final unconfiguredHistory = ReadHistoryService(database: database);
      addTearDown(unconfiguredFavorites.dispose);
      addTearDown(unconfiguredHistory.dispose);
      await unconfiguredFavorites.toggleFavorite(
        details: details,
        isAdding: true,
        folderId: folder.id,
      );
      await unconfiguredHistory.recordHistory(comic: comic, details: details);
      expect(
        (await favorites.loadFavoriteComics(
          page: 1,
          folderId: folder.id,
        )).comics.single.tags,
        ['action'],
      );
      expect(
        (await history.loadHistory(sourceKey: 'custom_tags')).single.tags,
        ['action'],
      );
    },
  );

  test(
    'local preferences preserve plugin-defined orders and sorting is generic',
    () async {
      await favorites.saveSortOrder('arbitrary_plugin_order');
      expect(await favorites.loadSortOrder(), 'arbitrary_plugin_order');
      await favorites.addFavoriteFolder('Folder', sourceKey: 'custom_tags');
      final folder = (await favorites.loadFavoriteFolders(
        sourceKey: 'custom_tags',
      )).folders.single;
      await favorites.toggleFavorite(
        details: _details('first', updated: '2026-10-14'),
        isAdding: true,
        folderId: folder.id,
      );
      await favorites.toggleFavorite(
        details: _details('second', updated: '2026-10-13'),
        isAdding: true,
        folderId: folder.id,
      );
      Future<List<String>> ids(String order) async =>
          (await favorites.loadFavoriteComics(
            page: 1,
            folderId: folder.id,
            sortOrder: order,
          )).comics.map((comic) => comic.id).toList();
      expect(await ids('savedNewest'), ['second', 'first']);
      expect(await ids('savedOldest'), ['first', 'second']);
      expect(await ids('updatedNewest'), ['first', 'second']);
    },
  );
}
