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
}

class _RecordingSource extends HazukiSourceService {
  _RecordingSource()
    : super(secureSessionStorage: MemorySourceSecureSessionStorage());

  Map<String, Object?>? searchArguments;
  Map<String, Object?>? imageArguments;

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
}
