import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/app/service_locator.dart';
import 'package:hazuki/features/history/state/history_page_controller.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/services/source/runtime/source_runtime_assembly.dart';
import 'package:hazuki/services/read_history_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/test_service_locator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(const {});
    await ensureTestServiceLocator();
  });

  tearDown(() async {
    await sl.reset();
  });

  test(
    'defers service-triggered reloads while auto reloads are paused',
    () async {
      final service = sl<ReadHistoryService>();
      await service.importJsonList([
        _historyJson(_comicA, timestamp: 1),
      ], replace: true);

      final controller = HistoryPageController(
        readHistoryService: service,
        sourceService: sl<SourceSelectionGateway>(),
      );
      addTearDown(controller.dispose);

      await controller.loadInitial();
      expect(controller.history.map((comic) => comic.id), ['a']);

      controller.pauseAutoReloads();
      await service.importJsonList([
        _historyJson(_comicB, timestamp: 2),
      ], replace: true);
      await Future<void>.delayed(Duration.zero);

      expect(controller.history.map((comic) => comic.id), ['a']);
      expect(controller.resumeAutoReloads(), isTrue);
      expect(controller.history.map((comic) => comic.id), ['a']);

      await controller.reload();

      expect(controller.history.map((comic) => comic.id), ['b']);
    },
  );

  test('backfills missing Picacg history tags', () async {
    final service = sl<ReadHistoryService>();
    sl<SourceRuntimeAssembly>().runtimeRegistry.activateSource('picacg');
    await service.importJsonList([
      {
        'id': 'picacg-comic',
        'title': 'Picacg comic',
        'sourceKey': 'picacg',
        'timestamp': 1,
      },
    ], replace: true);
    final reader = _ControlledReaderGateway();
    final controller = HistoryPageController(
      readHistoryService: service,
      sourceService: sl<SourceSelectionGateway>(),
      readerService: reader,
    );
    addTearDown(controller.dispose);
    final tagsLoaded = Completer<void>();
    controller.addListener(() {
      if (controller.history.singleOrNull?.tags.isNotEmpty == true &&
          !tagsLoaded.isCompleted) {
        tagsLoaded.complete();
      }
    });

    await controller.loadInitial();

    expect(controller.loading, isFalse);
    expect(controller.history.single.tags, isEmpty);
    reader.complete();
    await tagsLoaded.future;

    expect(controller.history.single.tags, ['Action', 'Romance']);
  });

  test('stops stale Picacg tag backfill before the next batch', () async {
    final service = sl<ReadHistoryService>();
    final runtime = sl<SourceRuntimeAssembly>().runtimeRegistry;
    runtime.activateSource('picacg');
    await service.importJsonList(
      List<Map<String, dynamic>>.generate(
        5,
        (index) => {
          'id': 'picacg-comic-$index',
          'title': 'Picacg comic $index',
          'sourceKey': 'picacg',
          'timestamp': 5 - index,
        },
      ),
      replace: true,
    );
    final reader = _ControlledReaderGateway();
    final controller = HistoryPageController(
      readHistoryService: service,
      sourceService: sl<SourceSelectionGateway>(),
      readerService: reader,
    );
    addTearDown(controller.dispose);

    await controller.loadInitial();
    expect(reader.calls, 4);

    runtime.activateSource(hazukiDefaultSourceKey);
    await Future<void>.delayed(Duration.zero);
    reader.complete();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(reader.calls, 4);
  });

  test(
    'silent reload updates history without enabling entry animation',
    () async {
      final service = sl<ReadHistoryService>();
      await service.importJsonList([
        _historyJson(_comicA, timestamp: 1),
      ], replace: true);

      final controller = HistoryPageController(
        readHistoryService: service,
        sourceService: sl<SourceSelectionGateway>(),
      );
      addTearDown(controller.dispose);

      await controller.loadInitial();
      controller.disableEntryAnimation();

      controller.pauseAutoReloads();
      await service.importJsonList([
        _historyJson(_comicB, timestamp: 2),
      ], replace: true);
      expect(controller.resumeAutoReloads(), isTrue);
      await controller.reload(playEntryAnimation: false);

      expect(controller.history.map((comic) => comic.id), ['b']);
      expect(controller.playItemEntryAnimation, isFalse);
    },
  );

  test('detail return reload preserves current history order', () async {
    final service = sl<ReadHistoryService>();
    await service.importJsonList([
      _historyJson(_comicA, timestamp: 2),
      _historyJson(_comicB, timestamp: 1),
    ], replace: true);

    final controller = HistoryPageController(
      readHistoryService: service,
      sourceService: sl<SourceSelectionGateway>(),
    );
    addTearDown(controller.dispose);

    await controller.loadInitial();
    expect(controller.history.map((comic) => comic.id), ['a', 'b']);

    controller.pauseAutoReloads();
    await service.importJsonList([
      _historyJson(_comicBUpdated, timestamp: 3),
      _historyJson(_comicA, timestamp: 2),
    ], replace: true);
    expect(controller.resumeAutoReloads(), isTrue);

    await controller.reload(
      playEntryAnimation: false,
      preserveExistingOrder: true,
    );

    expect(controller.history.map((comic) => comic.id), ['a', 'b']);
    expect(controller.history[1].title, 'B updated');
    expect(controller.playItemEntryAnimation, isFalse);
  });

  test(
    'delete keeps persisted timestamp order for the next full reload',
    () async {
      final service = sl<ReadHistoryService>();
      await service.importJsonList([
        _historyJson(_comicA, timestamp: 3),
        _historyJson(_comicB, timestamp: 2),
        _historyJson(_comicC, timestamp: 1),
      ], replace: true);

      final controller = HistoryPageController(
        readHistoryService: service,
        sourceService: sl<SourceSelectionGateway>(),
      );
      addTearDown(controller.dispose);

      await controller.loadInitial();
      expect(controller.history.map((comic) => comic.id), ['a', 'b', 'c']);

      await service.importJsonList([
        _historyJson(_comicCUpdated, timestamp: 4),
        _historyJson(_comicA, timestamp: 3),
        _historyJson(_comicB, timestamp: 2),
      ], replace: true);
      await controller.reload(
        preserveExistingOrder: true,
        playEntryAnimation: false,
      );
      expect(controller.history.map((comic) => comic.id), ['a', 'b', 'c']);

      await controller.deleteComic(_comicB);

      expect(controller.history.map((comic) => comic.id), ['a', 'c']);

      final reenteredController = HistoryPageController(
        readHistoryService: service,
        sourceService: sl<SourceSelectionGateway>(),
      );
      addTearDown(reenteredController.dispose);
      await reenteredController.loadInitial();

      expect(reenteredController.history.map((comic) => comic.id), ['c', 'a']);
      expect(reenteredController.history.first.title, 'C updated');
    },
  );
}

Map<String, Object> _historyJson(ExploreComic comic, {required int timestamp}) {
  return {
    'id': comic.id,
    'title': comic.title,
    'subTitle': comic.subTitle,
    'cover': comic.cover,
    'sourceKey': comic.sourceKey,
    'timestamp': timestamp,
  };
}

const _comicA = ExploreComic(
  id: 'a',
  title: 'A',
  subTitle: '',
  cover: '',
  sourceKey: hazukiDefaultSourceKey,
);

const _comicB = ExploreComic(
  id: 'b',
  title: 'B',
  subTitle: '',
  cover: '',
  sourceKey: hazukiDefaultSourceKey,
);

const _comicBUpdated = ExploreComic(
  id: 'b',
  title: 'B updated',
  subTitle: '',
  cover: '',
  sourceKey: hazukiDefaultSourceKey,
);

const _comicC = ExploreComic(
  id: 'c',
  title: 'C',
  subTitle: '',
  cover: '',
  sourceKey: hazukiDefaultSourceKey,
);

const _comicCUpdated = ExploreComic(
  id: 'c',
  title: 'C updated',
  subTitle: '',
  cover: '',
  sourceKey: hazukiDefaultSourceKey,
);

class _ControlledReaderGateway implements SourceReaderGateway {
  final _details = Completer<ComicDetailsData>();
  int calls = 0;

  void complete() => _details.complete(_picacgDetails);

  @override
  Future<ComicDetailsData> loadComicDetails(
    String comicId, {
    String sourceKey = '',
  }) {
    calls++;
    return _details.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _picacgDetails = ComicDetailsData(
  id: 'picacg-comic',
  title: 'Picacg comic',
  subTitle: '',
  cover: '',
  description: '',
  updateTime: '',
  likesCount: '',
  chapters: {},
  tags: {
    '标签': ['Action'],
    '分类': ['Romance'],
  },
  recommend: [],
  isFavorite: false,
  subId: '',
  sourceKey: 'picacg',
);
