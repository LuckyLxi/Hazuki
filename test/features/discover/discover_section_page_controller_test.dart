import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/discover/state/discover_section_page_controller.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/source/explore_capability.dart';
import 'package:hazuki/services/source/gateways/source_content_gateways.dart';
import 'package:hazuki/services/source/models/source_contract_models.dart';

void main() {
  test('marks only sections with a colliding category view-more parameter', () {
    final sections =
        SourceExploreCapability.markSectionsWithSharedCategoryViewMoreParameter(
          [
            _section('First', 'category:First@0'),
            _section('Second', 'category:Second@0'),
            _section('Han updates', 'category:Han updates@hanman'),
          ],
        );

    expect(sections.map((section) => section.offersInitialComicsFilter), [
      true,
      true,
      false,
    ]);
  });

  test(
    'defaults to the source preview while keeping normal category results available',
    () async {
      final source = _FakeDiscoverGateway();
      final preview = [_comic('preview')];
      final controller = DiscoverSectionPageController(
        sourceService: source,
        viewMoreUrl: 'category:Serial updates@0',
        initialComics: preview,
        initiallyOffersInitialComicsFilter: true,
      )..setInitialComicsFilterLabel('Home preview');

      await controller.loadSortOptionsAndInitial(
        loadFailedMessage: (error) => error,
      );

      expect(controller.sortOptions.map((option) => option.label), [
        'Home preview',
        'Latest',
      ]);
      expect(controller.comics.map((comic) => comic.id), ['preview']);
      expect(source.comicsRequestCount, 0);

      await controller.selectSortOptionInGroup(
        groupIndex: 0,
        value: controller.sortOptions[1].value,
      );

      expect(controller.comics.map((comic) => comic.id), ['remote']);
      expect(source.comicsRequestCount, 1);
    },
  );

  test('falls back to remote comics when loading sort options fails', () async {
    final source = _FakeDiscoverGateway()..throwOnOptionsLoad = true;
    final controller = DiscoverSectionPageController(
      sourceService: source,
      viewMoreUrl: 'category:Serial updates@0',
      initialComics: [_comic('preview')],
      initiallyOffersInitialComicsFilter: true,
    )..setInitialComicsFilterLabel('Home preview');

    await controller.loadSortOptionsAndInitial(
      loadFailedMessage: (error) => error,
    );

    expect(controller.sortOptionGroups, isEmpty);
    expect(controller.selectedSortValue, isNull);
    expect(source.lastOrders, isEmpty);
    expect(source.lastOrder, '');
    expect(controller.comics.map((comic) => comic.id), ['remote']);
    expect(source.comicsRequestCount, 1);
  });

  test('updates an existing source preview filter label', () async {
    final controller = DiscoverSectionPageController(
      sourceService: _FakeDiscoverGateway(),
      viewMoreUrl: 'category:Serial updates@0',
      initialComics: [_comic('preview')],
      initiallyOffersInitialComicsFilter: true,
    )..setInitialComicsFilterLabel('Home preview');

    await controller.loadSortOptionsAndInitial(
      loadFailedMessage: (error) => error,
    );
    controller.setInitialComicsFilterLabel('首页展示');

    expect(controller.sortOptions.first.label, '首页展示');
  });

  test('does not add the source preview filter when comics match', () async {
    final source = _FakeDiscoverGateway()..remoteComicId = 'preview';
    final controller = DiscoverSectionPageController(
      sourceService: source,
      viewMoreUrl: 'category:Han updates@hanman',
      initialComics: [_comic('preview')],
    )..setInitialComicsFilterLabel('Home preview');

    await controller.loadSortOptionsAndInitial(
      loadFailedMessage: (error) => error,
    );

    expect(controller.sortOptions.map((option) => option.label), ['Latest']);
  });

  test('keeps an empty first group selection before the sort group', () async {
    final source = _FakeDiscoverGateway()
      ..optionGroups = const [
        [CategoryRankingOption(value: '', label: 'All')],
        [CategoryRankingOption(value: 'score', label: 'Score')],
      ];
    final controller = DiscoverSectionPageController(
      sourceService: source,
      viewMoreUrl: 'category:genre',
    );
    addTearDown(controller.dispose);
    await controller.loadSortOptionsAndInitial(
      loadFailedMessage: (error) => error,
    );
    expect(controller.selectedSortValues, ['', 'score']);
    expect(source.lastOrders, ['', 'score']);
  });
}

ExploreComic _comic(String id) =>
    ExploreComic(id: id, title: id, subTitle: '', cover: '');

ExploreSection _section(String title, String viewMoreUrl) => ExploreSection(
  title: title,
  comics: [_comic(title)],
  viewMoreUrl: viewMoreUrl,
);

class _FakeDiscoverGateway extends ChangeNotifier
    implements SourceDiscoverGateway {
  @override
  bool get requiresLogin => false;
  @override
  String? get sourceRevision => activeSourceKey;
  int comicsRequestCount = 0;
  String remoteComicId = 'remote';
  bool throwOnOptionsLoad = false;
  List<List<CategoryRankingOption>> optionGroups = const [
    [CategoryRankingOption(value: 'latest', label: 'Latest')],
  ];
  List<String>? lastOrders;
  String? lastOrder;

  @override
  String get activeSourceKey => 'custom';

  @override
  bool get isLogged => false;

  @override
  SourceRuntimeState get sourceRuntimeState => const SourceRuntimeState.idle();

  @override
  void logRuntimeRetryRequested(String source) {}

  @override
  Future<List<ExploreSection>> loadExploreSections({
    bool forceRefresh = false,
  }) async => const [];

  @override
  Future<List<List<CategoryRankingOption>>> loadCategoryOptionGroupsByViewMore({
    required String viewMoreUrl,
  }) async {
    if (throwOnOptionsLoad) throw Exception('options unavailable');
    return optionGroups;
  }

  @override
  Future<CategoryComicsResult> loadCategoryComicsByViewMore({
    required String viewMoreUrl,
    required int page,
    String order = '',
    List<String>? orders,
  }) async {
    comicsRequestCount++;
    lastOrder = order;
    lastOrders = orders;
    return CategoryComicsResult(comics: [_comic(remoteComicId)], maxPage: 1);
  }
}
