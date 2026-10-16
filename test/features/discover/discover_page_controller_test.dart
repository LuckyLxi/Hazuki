import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/app/service_locator.dart';
import 'package:hazuki/features/discover/state/discover_page_controller.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/source/runtime/source_runtime_assembly.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import '../../support/test_service_locator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    await ensureTestServiceLocator();
  });

  test('forwards source service changes until disposed', () {
    final controller = DiscoverPageController(
      sourceService: sl<SourceDiscoverGateway>(),
    );
    var notifications = 0;
    controller.addListener(() {
      notifications++;
    });

    // ignore: invalid_use_of_protected_member
    sl<SourceRuntimeAssembly>().testing.notifyRuntimeView();

    expect(notifications, 1);

    controller.dispose();
    // ignore: invalid_use_of_protected_member
    sl<SourceRuntimeAssembly>().testing.notifyRuntimeView();

    expect(notifications, 1);
  });

  for (final initialPage in [0, 1]) {
    test(
      'continues past a full first page with initialPage=$initialPage',
      () async {
        final source = _DiscoverGateway(
          section: ExploreSection(
            title: 'Comics',
            comics: _comics(0, 7),
            viewMoreUrl: 'category:comics',
            initialPage: initialPage,
          ),
          pages: {
            1: CategoryComicsResult(comics: _comics(0, 7), maxPage: 2),
            2: CategoryComicsResult(comics: _comics(7, 7), maxPage: 2),
          },
        );
        final controller = DiscoverPageController(sourceService: source);
        addTearDown(controller.dispose);
        addTearDown(source.dispose);
        await _load(controller);
        await controller.loadMoreSection(0);
        expect(source.requestedPages, initialPage == 0 ? [1, 2] : [2]);
        expect(controller.sections.single.comics.map((comic) => comic.id), [
          for (var i = 0; i < 14; i++) '$i',
        ]);
        expect(controller.sectionHasMore(0), isFalse);
        expect(controller.isSectionLoadingMore(0), isFalse);

        await controller.refresh(
          timeoutMessage: 'timeout',
          loadFailedMessage: (error) => error,
        );
        source.requestedPages.clear();
        await controller.loadMoreSection(0);
        expect(source.requestedPages, initialPage == 0 ? [1, 2] : [2]);
        expect(controller.sections.single.comics, hasLength(14));
      },
    );
  }

  for (final empty in [false, true]) {
    test('preview finishes on a single catalog page (empty=$empty)', () async {
      final source = _DiscoverGateway(
        section: ExploreSection(
          title: 'Preview',
          comics: _comics(0, 7),
          viewMoreUrl: 'category:comics',
          initialPage: 0,
          maxPage: 1,
        ),
        pages: {
          1: CategoryComicsResult(
            comics: empty ? [] : _comics(0, 12),
            maxPage: 1,
          ),
        },
      );
      final controller = DiscoverPageController(sourceService: source);
      addTearDown(controller.dispose);
      addTearDown(source.dispose);
      await _load(controller);
      expect(controller.sectionHasMore(0), isTrue);
      await controller.loadMoreSection(0);
      expect(source.requestedPages, [1]);
      expect(controller.sections.single.comics, hasLength(empty ? 7 : 12));
      expect(controller.sectionHasMore(0), isFalse);
      await controller.loadMoreSection(0);
      expect(source.requestedPages, [1]);
    });
  }

  test(
    'duplicate pages without a page count stop after preview catch-up',
    () async {
      final source = _DiscoverGateway(
        section: ExploreSection(
          title: 'Preview',
          comics: _comics(0, 7),
          viewMoreUrl: 'category:comics',
          initialPage: 0,
        ),
        pages: {
          1: CategoryComicsResult(comics: _comics(0, 7), maxPage: null),
          2: CategoryComicsResult(comics: _comics(0, 7), maxPage: null),
        },
      );
      final controller = DiscoverPageController(sourceService: source);
      addTearDown(controller.dispose);
      addTearDown(source.dispose);
      await _load(controller);
      await controller.loadMoreSection(0);
      expect(source.requestedPages, [1, 2]);
      expect(controller.sections.single.comics, hasLength(7));
      expect(controller.sectionHasMore(0), isFalse);
    },
  );
}

Future<void> _load(DiscoverPageController controller) => controller.loadInitial(
  timeoutMessage: 'timeout',
  loadFailedMessage: (error) => error,
);

List<ExploreComic> _comics(int start, int count) => List.generate(
  count,
  (index) => ExploreComic(
    id: '${start + index}',
    title: 'Comic ${start + index}',
    subTitle: '',
    cover: '',
    sourceKey: 'test',
  ),
);

class _DiscoverGateway extends ChangeNotifier implements SourceDiscoverGateway {
  _DiscoverGateway({required this.section, required this.pages});

  final ExploreSection section;
  final Map<int, CategoryComicsResult> pages;
  final requestedPages = <int>[];

  @override
  String get activeSourceKey => 'test';
  @override
  String? get sourceRevision => null;
  @override
  bool get requiresLogin => false;
  @override
  bool get isLogged => false;
  @override
  SourceRuntimeState get sourceRuntimeState => const SourceRuntimeState.idle();
  @override
  void logRuntimeRetryRequested(String source) {}
  @override
  Future<List<ExploreSection>> loadExploreSections({
    bool forceRefresh = false,
  }) async => [section];
  @override
  Future<List<List<CategoryRankingOption>>> loadCategoryOptionGroupsByViewMore({
    required String viewMoreUrl,
  }) async => [];
  @override
  Future<CategoryComicsResult> loadCategoryComicsByViewMore({
    required String viewMoreUrl,
    required int page,
    String order = '',
    List<String>? orders,
  }) async {
    requestedPages.add(page);
    return pages[page]!;
  }
}
