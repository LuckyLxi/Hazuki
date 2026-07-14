import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/app/service_locator.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/hazuki_source_service.dart';
import 'package:hazuki/services/source/runtime/source_secure_session_storage.dart';
import 'package:hazuki/services/source/source_capabilities.dart';

import '../../support/test_service_locator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() async {
    await sl.reset();
  });

  test(
    'service locator registers a focused adapter for every gateway',
    () async {
      await ensureTestServiceLocator();

      expect(sl<SourceSearchGateway>(), isA<HazukiSourceSearchAdapter>());
      expect(sl<SourceDiscoverGateway>(), isA<HazukiSourceDiscoverAdapter>());
      expect(sl<SourceFavoriteGateway>(), isA<HazukiSourceFavoriteAdapter>());
      expect(sl<SourceReaderGateway>(), isA<HazukiSourceReaderAdapter>());
      expect(sl<SourceSettingsGateway>(), isA<HazukiSourceSettingsAdapter>());
      expect(sl<SourceAccountGateway>(), isA<HazukiSourceAccountAdapter>());
      expect(sl<SourceDebugGateway>(), isA<HazukiSourceDebugAdapter>());
      expect(sl<SourceImageGateway>(), isA<HazukiSourceImageAdapter>());
      expect(
        sl<SourceRecommendationGateway>(),
        isA<HazukiSourceRecommendationAdapter>(),
      );
      expect(
        sl<SourceDailyRecommendationGateway>(),
        isA<HazukiSourceDailyRecommendationAdapter>(),
      );
      expect(sl<SourceSyncGateway>(), isA<HazukiSourceSyncAdapter>());
      expect(sl<SourceRuntimeGateway>(), isA<HazukiSourceRuntimeAdapter>());
      expect(sl<SourceCategoryGateway>(), isA<HazukiSourceCategoryAdapter>());
      expect(sl<SourceCommentsGateway>(), isA<HazukiSourceCommentsAdapter>());
      expect(
        sl<SourceComicDetailGateway>(),
        isA<HazukiSourceComicDetailAdapter>(),
      );
    },
  );

  test('listenable adapters forward source notifications', () {
    final source = _RecordingSource();
    final adapter = HazukiSourceSearchAdapter(source);
    var notifications = 0;

    void listener() => notifications++;
    adapter.addListener(listener);
    source.notifyListeners();
    adapter.removeListener(listener);
    source.notifyListeners();

    expect(notifications, 1);
  });

  test('search adapter preserves arguments and result', () async {
    final source = _RecordingSource();
    final adapter = HazukiSourceSearchAdapter(source);

    final result = await adapter.searchComics(
      keyword: 'artist',
      page: 3,
      order: 'dd',
      sourceKey: 'copy_manga',
    );

    expect(result.maxPage, 9);
    expect(source.searchArguments, {
      'keyword': 'artist',
      'page': 3,
      'order': 'dd',
      'sourceKey': 'copy_manga',
    });
  });

  test('image adapter preserves cache and source arguments', () async {
    final source = _RecordingSource();
    final adapter = HazukiSourceImageAdapter(source);

    final bytes = await adapter.downloadImageBytes(
      'https://example.test/image.jpg',
      comicId: 'comic',
      epId: 'chapter',
      keepInMemory: true,
      useDiskCache: false,
      sourceKey: 'picacg',
    );

    expect(bytes, Uint8List.fromList([1, 2, 3]));
    expect(source.imageArguments, {
      'url': 'https://example.test/image.jpg',
      'comicId': 'comic',
      'epId': 'chapter',
      'keepInMemory': true,
      'useDiskCache': false,
      'priority': false,
      'sourceKey': 'picacg',
    });
  });

  test('category adapter preserves the requested source scope', () async {
    final source = _RecordingSource();
    final adapter = HazukiSourceCategoryAdapter(source);

    await adapter.loadCategoryTagGroups(
      forceRefresh: true,
      sourceKey: 'picacg',
    );

    expect(source.categoryTagArguments, {
      'forceRefresh': true,
      'sourceKey': 'picacg',
    });
  });

  test(
    'favorite adapter preserves folder, sorting, and source arguments',
    () async {
      final source = _RecordingSource();
      final adapter = HazukiSourceFavoriteAdapter(source);

      await adapter.loadFavoriteFolders(
        comicId: 'comic',
        sourceKey: 'copy_manga',
      );
      await adapter.loadFavoriteComics(page: 3, folderId: 'folder');
      await adapter.toggleFavorite(
        comicId: 'comic',
        isAdding: true,
        folderId: 'folder',
        favoriteId: 'remote',
        sourceKey: 'copy_manga',
      );
      await adapter.setFavoriteSortOrder('da');

      expect(source.favoriteFolderArguments, {
        'comicId': 'comic',
        'sourceKey': 'copy_manga',
      });
      expect(source.favoriteComicsArguments, {'page': 3, 'folderId': 'folder'});
      expect(source.favoriteToggleArguments, {
        'comicId': 'comic',
        'isAdding': true,
        'folderId': 'folder',
        'favoriteId': 'remote',
        'sourceKey': 'copy_manga',
      });
      expect(source.favoriteSortOrderArgument, 'da');
    },
  );

  test('account and runtime adapters forward daily check-in calls', () async {
    final source = _RecordingSource();
    final account = HazukiSourceAccountAdapter(source);
    final runtime = HazukiSourceRuntimeAdapter(source);

    expect(await account.isDailyCheckInCompletedToday(), isTrue);
    expect(
      (await runtime.performDailyCheckIn()).status,
      DailyCheckInStatus.alreadyCheckedIn,
    );
    expect(source.dailyCheckInCompletionCalls, 1);
    expect(source.dailyCheckInPerformCalls, 1);
  });
}

class _RecordingSource extends HazukiSourceService {
  _RecordingSource()
    : super(secureSessionStorage: MemorySourceSecureSessionStorage());

  Map<String, Object?>? searchArguments;
  Map<String, Object?>? imageArguments;
  Map<String, Object?>? categoryTagArguments;
  Map<String, Object?>? favoriteFolderArguments;
  Map<String, Object?>? favoriteComicsArguments;
  Map<String, Object?>? favoriteToggleArguments;
  String? favoriteSortOrderArgument;
  int dailyCheckInCompletionCalls = 0;
  int dailyCheckInPerformCalls = 0;

  @override
  Future<SearchComicsResult> searchComics({
    required String keyword,
    required int page,
    String order = 'mr',
    String sourceKey = '',
  }) async {
    searchArguments = {
      'keyword': keyword,
      'page': page,
      'order': order,
      'sourceKey': sourceKey,
    };
    return const SearchComicsResult(comics: [], maxPage: 9);
  }

  @override
  Future<Uint8List> downloadImageBytes(
    String url, {
    String? comicId,
    String? epId,
    bool keepInMemory = false,
    bool useDiskCache = true,
    bool priority = false,
    String sourceKey = '',
  }) async {
    imageArguments = {
      'url': url,
      'comicId': comicId,
      'epId': epId,
      'keepInMemory': keepInMemory,
      'useDiskCache': useDiskCache,
      'priority': priority,
      'sourceKey': sourceKey,
    };
    return Uint8List.fromList([1, 2, 3]);
  }

  @override
  Future<List<CategoryTagGroup>> loadCategoryTagGroups({
    bool forceRefresh = false,
    String sourceKey = '',
  }) async {
    categoryTagArguments = {
      'forceRefresh': forceRefresh,
      'sourceKey': sourceKey,
    };
    return const [];
  }

  @override
  Future<FavoriteFoldersResult> loadFavoriteFolders({
    String? comicId,
    String sourceKey = '',
  }) async {
    favoriteFolderArguments = {'comicId': comicId, 'sourceKey': sourceKey};
    return const FavoriteFoldersResult.success(
      folders: [],
      favoritedFolderIds: {},
    );
  }

  @override
  Future<FavoriteComicsResult> loadFavoriteComics({
    required int page,
    required String folderId,
  }) async {
    favoriteComicsArguments = {'page': page, 'folderId': folderId};
    return const FavoriteComicsResult.success([]);
  }

  @override
  Future<void> toggleFavorite({
    required String comicId,
    required bool isAdding,
    String folderId = '0',
    String? favoriteId,
    String sourceKey = '',
  }) async {
    favoriteToggleArguments = {
      'comicId': comicId,
      'isAdding': isAdding,
      'folderId': folderId,
      'favoriteId': favoriteId,
      'sourceKey': sourceKey,
    };
  }

  @override
  Future<void> setFavoriteSortOrder(String order) async {
    favoriteSortOrderArgument = order;
  }

  @override
  Future<bool> isDailyCheckInCompletedToday() async {
    dailyCheckInCompletionCalls++;
    return true;
  }

  @override
  Future<DailyCheckInResult> performDailyCheckIn() async {
    dailyCheckInPerformCalls++;
    return const DailyCheckInResult.alreadyCheckedIn();
  }
}
