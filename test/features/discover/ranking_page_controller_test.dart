import 'package:hazuki/services/source/interaction/source_ui_service.dart';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/discover/state/ranking_page_controller.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/source/source_capabilities.dart';

import '../../support/fake_source_task_control.dart';

late SourceUiService sourceUiService;

void main() {
  setUp(() {
    sourceUiService = SourceUiService();
  });
  tearDown(() {
    sourceUiService.detach();
  });
  late _RankingSource source;
  late RankingPageController controller;
  var disposed = false;

  setUp(() {
    source = _RankingSource();
    controller = RankingPageController(
      sourceUiService: sourceUiService,
      sourceService: source,
      taskControl: FakeSourceTaskControl(),
      optionsTimeoutMessage: () => 'options timed out',
      pageTimeoutMessage: () => 'page timed out',
      loadFailedMessage: (error) => 'Load failed: $error',
    );
    disposed = false;
    addTearDown(() {
      if (!disposed) controller.dispose();
    });
  });

  test('loads the first ranking and preserves selection on refresh', () async {
    expect(controller.initialLoading, isTrue);
    await controller.loadInitial();
    expect(controller.initialLoading, isFalse);
    expect(controller.selectedRanking, 'daily');
    expect(controller.comics.single.id, 'daily');

    await controller.selectRanking('weekly');
    final refresh = controller.loadInitial(forceRefresh: true);
    expect(controller.refreshing, isTrue);
    await refresh;
    expect(controller.refreshing, isFalse);
    expect(controller.selectedRanking, 'weekly');
    expect(controller.comics.single.id, 'weekly');
    expect(source.requests.map((request) => (request.ranking, request.page)), [
      ('daily', 1),
      ('weekly', 1),
      ('weekly', 1),
    ]);
  });

  test('empty options finish loading without requesting comics', () async {
    source.loadOptions = () async => const [];

    await controller.loadInitial();
    await controller.loadMore();

    expect(controller.initialLoading, isFalse);
    expect(controller.selectedRanking, isNull);
    expect(controller.comics, isEmpty);
    expect(controller.hasMore, isFalse);
    expect(source.requests, isEmpty);
  });

  test(
    'pagination updates duplicates and stops when no comics are added',
    () async {
      source.loadPage = (_, page) async => switch (page) {
        1 => _page([_comic('a')]),
        2 => _page([_comic('a', title: 'updated'), _comic('b')]),
        3 => _page([_comic('b')]),
        _ => throw StateError('unexpected page $page'),
      };

      await controller.loadInitial();
      await controller.loadMore();
      expect(controller.comics.map((comic) => comic.id), ['a', 'b']);
      expect(controller.comics.first.title, 'updated');
      expect(controller.hasMore, isTrue);
      await controller.loadMore();
      await controller.loadMore();

      expect(controller.comics.map((comic) => comic.id), ['a', 'b']);
      expect(controller.hasMore, isFalse);
      expect(source.requests.map((request) => request.page), [1, 2, 3]);
    },
  );

  test(
    'switching ranking cancels an old page and ignores its late result',
    () async {
      final oldPage = Completer<CategoryComicsResult>();
      source.loadPage = (ranking, page) async =>
          page == 2 ? oldPage.future : _page([_comic(ranking)]);
      await controller.loadInitial();
      final pending = controller.loadMore();
      final oldOrigin = source.requests.last.origin;
      expect(controller.loadingMore, isTrue);

      await controller.selectRanking('weekly');
      oldPage.complete(_page([_comic('stale')]));
      await pending;

      expect(oldOrigin.cancellation?.reason, SourceTaskStopReason.superseded);
      expect(controller.comics.single.id, 'weekly');
      expect(controller.loadingMore, isFalse);
      expect(controller.errorMessage, isNull);
    },
  );

  test(
    'a page failure preserves earlier results and retries the same page',
    () async {
      await controller.loadInitial();
      source.loadPage = (_, _) async => throw StateError('offline');
      await controller.loadMore();
      expect(controller.errorMessage, contains('offline'));
      expect(controller.comics.single.id, 'daily');
      expect(controller.loadingMore, isFalse);
      expect(controller.hasMore, isTrue);

      source.loadPage = (_, _) async => _page([_comic('last')], maxPage: 2);
      await controller.loadMore();
      expect(source.requests.map((request) => request.page), [1, 2, 2]);
      expect(controller.errorMessage, isNull);
      expect(controller.hasMore, isFalse);
    },
  );

  for (final options in [true, false]) {
    testWidgets('${options ? 'options' : 'page'} time out after 25 seconds', (
      tester,
    ) async {
      final pendingOptions = Completer<List<CategoryRankingOption>>();
      final pendingPage = Completer<CategoryComicsResult>();
      if (options) {
        source.loadOptions = () => pendingOptions.future;
      } else {
        source.loadPage = (_, _) => pendingPage.future;
      }
      final pending = controller.loadInitial();
      await tester.pump();
      await tester.pump(const Duration(seconds: 24));
      expect(controller.initialLoading, isTrue);
      expect(controller.errorMessage, isNull);
      await tester.pump(const Duration(seconds: 1));
      await pending;
      expect(controller.initialLoading, isFalse);
      expect(
        controller.errorMessage,
        contains(options ? 'options timed out' : 'page timed out'),
      );
    });
  }

  test(
    'dispose cancels the request and discards its eventual result',
    () async {
      final result = Completer<CategoryComicsResult>();
      source.loadPage = (_, _) => result.future;
      final pending = controller.loadInitial();
      await Future<void>.delayed(Duration.zero);
      final origin = source.requests.single.origin;
      var notifications = 0;
      controller.addListener(() => notifications++);

      controller.dispose();
      disposed = true;
      result.complete(_page([_comic('late')]));
      await pending;

      expect(origin.cancellation?.reason, SourceTaskStopReason.ownerDisposed);
      expect(notifications, 0);
      expect(controller.comics, isEmpty);
    },
  );
}

ExploreComic _comic(String id, {String? title}) =>
    ExploreComic(id: id, title: title ?? id, subTitle: '', cover: '');

CategoryComicsResult _page(List<ExploreComic> comics, {int? maxPage}) =>
    CategoryComicsResult(comics: comics, maxPage: maxPage);

class _RankingSource extends Fake implements SourceCategoryGateway {
  Future<List<CategoryRankingOption>> Function() loadOptions = () async =>
      const [
        CategoryRankingOption(value: 'daily', label: 'Daily'),
        CategoryRankingOption(value: 'weekly', label: 'Weekly'),
      ];
  Future<CategoryComicsResult> Function(String, int) loadPage =
      (ranking, _) async => _page([_comic(ranking)]);
  final requests = <({String ranking, int page, SourceTaskOrigin origin})>[];

  @override
  Future<List<CategoryRankingOption>> loadCategoryRankingOptions({
    SourceTaskOrigin? taskOrigin,
  }) => loadOptions();

  @override
  Future<CategoryComicsResult> loadCategoryRankingComics({
    required String rankingOption,
    required int page,
    SourceTaskOrigin? taskOrigin,
  }) {
    requests.add((ranking: rankingOption, page: page, origin: taskOrigin!));
    return loadPage(rankingOption, page);
  }
}
