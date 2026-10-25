import '../../support/fake_source_task_control.dart';
import 'package:hazuki/services/source/models/source_task.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/discover/state/discover_section_page_controller.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/source/gateways/source_content_gateways.dart';
import 'package:hazuki/services/source/models/source_contract_models.dart';

void main() {
  test('loads remote comics without a home preview filter', () async {
    final source = _FakeDiscoverGateway();
    final controller = DiscoverSectionPageController(
      sourceService: source,
      viewMoreUrl: 'category:Serial updates@0',
      initialComics: [_comic('preview')],
      taskControl: FakeSourceTaskControl(),
    );
    addTearDown(controller.dispose);

    await controller.loadSortOptionsAndInitial(
      loadFailedMessage: (error) => error,
    );

    expect(controller.sortOptions.map((option) => option.label), ['Latest']);
    expect(controller.comics.map((comic) => comic.id), ['remote']);
    expect(source.comicsRequestCount, 1);
  });

  test('falls back to remote comics when loading sort options fails', () async {
    final source = _FakeDiscoverGateway()..throwOnOptionsLoad = true;
    final controller = DiscoverSectionPageController(
      sourceService: source,
      viewMoreUrl: 'category:Serial updates@0',
      initialComics: [_comic('preview')],
      taskControl: FakeSourceTaskControl(),
    );
    addTearDown(controller.dispose);

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

  test('keeps an empty first group selection before the sort group', () async {
    final source = _FakeDiscoverGateway()
      ..optionGroups = const [
        [CategoryRankingOption(value: '', label: 'All')],
        [CategoryRankingOption(value: 'score', label: 'Score')],
      ];
    final controller = DiscoverSectionPageController(
      sourceService: source,
      viewMoreUrl: 'category:genre',
      taskControl: FakeSourceTaskControl(),
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
  SourceRuntimeState get runtimeState => const SourceRuntimeState.idle();

  @override
  void logRuntimeRetryRequested(String source) {}

  @override
  Future<List<ExploreSection>> loadExploreSections({
    bool forceRefresh = false,
    SourceTaskOrigin? taskOrigin,
  }) async => const [];

  @override
  Future<List<List<CategoryRankingOption>>> loadCategoryOptionGroupsByViewMore({
    required String viewMoreUrl,
    SourceTaskOrigin? taskOrigin,
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
    SourceTaskOrigin? taskOrigin,
  }) async {
    comicsRequestCount++;
    lastOrder = order;
    lastOrders = orders;
    return CategoryComicsResult(comics: [_comic(remoteComicId)], maxPage: 1);
  }
}
