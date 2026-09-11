import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/features/comic_detail/view/comic_detail_page.dart';
import 'package:hazuki/features/comic_detail/view/comic_detail_header_cover.dart';
import 'package:hazuki/features/comic_detail/view/comic_detail_header_action_row.dart';
import 'package:hazuki/features/comic_detail/view/comic_detail_related_tab.dart';
import 'package:hazuki/features/comic_detail/view/comic_detail_related_tile.dart';
import 'package:hazuki/features/comic_detail/view/comic_detail_meta.dart';
import 'package:hazuki/features/comic_detail/view/comic_detail_expandable_description.dart';
import 'package:hazuki/features/comic_detail/view/comic_detail_view_primitives.dart';
import 'package:hazuki/features/comic_detail/repository/comic_detail_repository.dart';
import 'package:hazuki/features/comic_detail/support/comic_detail_dependencies.dart';
import 'package:hazuki/features/comic_detail/support/comic_detail_reveal_registry.dart';
import 'package:hazuki/features/reader/support/reader_dependencies.dart';
import 'package:hazuki/features/reader/view/reader_page.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/app/service_locator.dart';
import 'package:hazuki/services/manga_download/manga_download_service.dart';
import 'package:hazuki/services/local_favorites/local_favorites_contracts.dart';
import 'package:hazuki/services/read_history_service.dart';
import 'package:hazuki/services/reading_progress_service.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/shared/comments/comments_widget_builder.dart';
import 'package:hazuki/shared/comments/comments_interaction_state.dart';
import 'package:hazuki/widgets/cached_image_widgets.dart';
import '../../support/test_service_locator.dart';

Widget _buildComments({
  required String comicId,
  String? subId,
  String? chapterId,
  required String sourceKey,
  ScrollController? scrollController,
  Future<void> Function()? onRequestTabFullscreen,
  bool showAppBar = false,
  bool isTabView = false,
  bool isActiveInTabView = true,
  Map<String, Object?> Function()? debugOuterScrollStateBuilder,
  CommentsInteractionState? interactionState,
}) {
  return const SizedBox.shrink();
}

final ReaderCommentsWidgetBuilder _buildReaderComments =
    readerCommentsWidgetBuilderFrom(_buildComments);

ReaderDependencies _readerDependencies() {
  return ReaderDependencies(
    sourceReader: sl<SourceReaderGateway>(),
    sourceSettings: sl<SourceSettingsGateway>(),
    readingProgressService: sl<ReadingProgressService>(),
    downloader: sl<MangaDownloadService>(),
  );
}

ComicDetailDependencies _comicDetailDependencies() {
  return ComicDetailDependencies(
    source: sl<SourceComicDetailGateway>(),
    localFavorites: sl<LocalFavoritesRepository>(),
    downloader: sl<MangaDownloadService>(),
    readingProgress: sl<ReadingProgressService>(),
    readHistory: sl<ReadHistoryService>(),
    imageGateway: sl<SourceImageGateway>(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ensureTestServiceLocator();
  });
  for (final brightness in Brightness.values) {
    testWidgets('Windows detail adapts to resize in $brightness', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            platform: TargetPlatform.windows,
            brightness: brightness,
          ),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ComicDetailPage(
            comic: const ExploreComic(
              id: 'desktop-layout',
              sourceKey: 'copy_manga',
              title:
                  'A long comic title that should wrap naturally on a narrow window',
              subTitle: 'An illustrated journey',
              cover: '',
            ),
            dependencies: _comicDetailDependencies(),
            repository: _DesktopDetailFacade(),
            heroTag: 'desktop-layout',
            shouldAnimateInitialRevealOverride: false,
            readerWidgetBuilder:
                ({
                  required title,
                  required chapterTitle,
                  required comicId,
                  required epId,
                  required chapterIndex,
                  required images,
                  required sourceKey,
                  coverUrl = '',
                  comicTheme,
                  onFavoriteRequested,
                }) => const Scaffold(body: Text('Reader destination')),
            searchPageBuilder: (_) => const SizedBox.shrink(),
            commentsWidgetBuilder: _buildComments,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final cover = find.byType(ComicDetailHeaderCover);
      final actions = find.byType(ComicDetailHeaderActionRow);
      final summary = find.byType(ComicDetailExpandableDescription);
      final metadata = find.byType(ComicDetailMetaSection);
      expect(tester.getSize(cover).width, 210);
      expect(
        tester.getTopLeft(actions).dx,
        greaterThan(tester.getTopRight(cover).dx),
      );
      expect(tester.getSize(actions).width, lessThanOrEqualTo(420));
      final favoriteButton = find.widgetWithIcon(
        OutlinedButton,
        Icons.favorite_border,
      );
      expect(favoriteButton, findsOneWidget);
      expect(
        tester.getTopLeft(favoriteButton).dx,
        closeTo(tester.getTopLeft(actions).dx, 1),
      );
      expect(
        tester.getTopLeft(metadata).dx,
        greaterThan(tester.getTopRight(summary).dx),
      );

      tester.view.physicalSize = const Size(560, 1000);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.getSize(cover).width, 135);
      expect(
        tester.getTopLeft(actions).dy,
        greaterThan(tester.getBottomLeft(cover).dy),
      );
      expect(
        tester.getTopLeft(metadata).dy,
        greaterThan(tester.getBottomLeft(summary).dy),
      );

      await tester.tap(find.byType(Tab).at(1));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byType(Tab).first);
      await tester.pumpAndSettle();
      expect(find.byType(ComicDetailMetaSection), findsOneWidget);
    });
  }
  testWidgets(
    'Windows detail keeps action layout stable and reveals resolved content',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final facade = _CompletingDesktopDetailFacade();

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.windows),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ComicDetailPage(
            comic: const ExploreComic(
              id: 'desktop-loading-reveal',
              sourceKey: 'copy_manga',
              title: 'Stable title',
              subTitle: 'Stable subtitle',
              cover: '',
            ),
            dependencies: _comicDetailDependencies(),
            repository: facade,
            heroTag: 'desktop-loading-reveal',
            shouldAnimateInitialRevealOverride: true,
            readerWidgetBuilder:
                ({
                  required title,
                  required chapterTitle,
                  required comicId,
                  required epId,
                  required chapterIndex,
                  required images,
                  required sourceKey,
                  coverUrl = '',
                  comicTheme,
                  onFavoriteRequested,
                }) => const SizedBox.shrink(),
            searchPageBuilder: (_) => const SizedBox.shrink(),
            commentsWidgetBuilder: _buildComments,
          ),
        ),
      );
      await tester.pump();

      final actions = find.byType(ComicDetailHeaderActionRow);
      final loadingTop = tester.getTopLeft(actions).dy;
      final actionSlide = find.descendant(
        of: actions,
        matching: find.byType(AnimatedSlide),
      );
      expect(tester.widget<AnimatedSlide>(actionSlide).offset.dy, -0.08);
      facade.complete();
      await tester.pump();
      expect(tester.widget<AnimatedSlide>(actionSlide).offset, Offset.zero);

      final reveal = find.byType(ComicDetailEntranceReveal);
      expect(reveal, findsOneWidget);
      final opacity = find.descendant(
        of: reveal,
        matching: find.byType(Opacity),
      );
      expect(opacity, findsOneWidget);
      expect(tester.widget<Opacity>(opacity).opacity, 0);

      await tester.pump(const Duration(milliseconds: 160));
      expect(tester.widget<Opacity>(opacity).opacity, inExclusiveRange(0, 1));
      await tester.pumpAndSettle();

      // AnimatedSlide keeps the intended paint-only reveal while the reserved
      // stats slot prevents any additional layout displacement.
      expect(tester.getTopLeft(actions).dy, closeTo(loadingTop, 0.5));
      expect(tester.widget<Opacity>(opacity).opacity, 1);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Windows detail animates actions when resolved title is shorter', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final facade = _CompletingDesktopDetailFacade();

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.windows),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ComicDetailPage(
          comic: const ExploreComic(
            id: 'desktop-title-resize',
            sourceKey: 'copy_manga',
            title:
                'A deliberately long loading title that wraps across several lines '
                'so the controls need to move upward when the shorter resolved title arrives',
            subTitle: 'Stable subtitle',
            cover: '',
          ),
          dependencies: _comicDetailDependencies(),
          repository: facade,
          heroTag: 'desktop-title-resize',
          shouldAnimateInitialRevealOverride: true,
          readerWidgetBuilder:
              ({
                required title,
                required chapterTitle,
                required comicId,
                required epId,
                required chapterIndex,
                required images,
                required sourceKey,
                coverUrl = '',
                comicTheme,
                onFavoriteRequested,
              }) => const SizedBox.shrink(),
          searchPageBuilder: (_) => const SizedBox.shrink(),
          commentsWidgetBuilder: _buildComments,
        ),
      ),
    );
    await tester.pump();

    final actions = find.byType(ComicDetailHeaderActionRow);
    final loadingTop = tester.getTopLeft(actions).dy;
    facade.complete(title: 'Short title');
    await tester.pump();
    final animationStartTop = tester.getTopLeft(actions).dy;
    await tester.pump(const Duration(milliseconds: 160));
    final animationMiddleTop = tester.getTopLeft(actions).dy;
    await tester.pumpAndSettle();
    final resolvedTop = tester.getTopLeft(actions).dy;

    expect(animationStartTop, closeTo(loadingTop, 0.5));
    expect(animationMiddleTop, lessThan(animationStartTop));
    expect(animationMiddleTop, greaterThan(resolvedTop));
    expect(resolvedTop, lessThan(loadingTop));
    expect(tester.takeException(), isNull);
  });
  testWidgets('Windows restored detail does not animate tabs or action reveal', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final facade = _CompletingDesktopDetailFacade();

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.windows),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: _buildDesktopTestDetail(
          comic: const ExploreComic(
            id: 'desktop-restored-settle',
            sourceKey: 'copy_manga',
            title:
                'A deliberately long restored title that wraps over several lines '
                'before the resolved cached details settle the tab area upward',
            subTitle: 'Stable subtitle',
            cover: '',
          ),
          facade: facade,
          shouldAnimateInitialRevealOverride: false,
        ),
      ),
    );
    await tester.pump();

    final actions = find.byType(ComicDetailHeaderActionRow);
    final actionSlide = find.descendant(
      of: actions,
      matching: find.byType(AnimatedSlide),
    );
    final tabBar = find.byType(TabBar);
    final loadingTabTop = tester.getTopLeft(tabBar).dy;
    expect(tester.widget<AnimatedSlide>(actionSlide).offset, Offset.zero);

    facade.complete(title: 'Short restored title');
    await tester.pump();
    await tester.pump();
    final resolvedTabTop = tester.getTopLeft(tabBar).dy;
    await tester.pump(const Duration(milliseconds: 160));
    final delayedTabTop = tester.getTopLeft(tabBar).dy;

    expect(resolvedTabTop, lessThan(loadingTabTop));
    expect(delayedTabTop, closeTo(resolvedTabTop, 0.5));
    expect(tester.widget<AnimatedSlide>(actionSlide).offset, Offset.zero);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Windows cached related detail does not replay reveal animations',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const comicId = 'desktop-cached-related';
      markComicDetailIdAnimated(comicId);
      final facade = _CompletingDesktopDetailFacade();

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.windows),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: _buildDesktopTestDetail(
            comic: const ExploreComic(
              id: comicId,
              sourceKey: 'copy_manga',
              title: 'Cached title',
              subTitle: 'Cached subtitle',
              cover: '',
            ),
            facade: facade,
          ),
        ),
      );
      await tester.pump();

      final actions = find.byType(ComicDetailHeaderActionRow);
      final actionSlide = find.descendant(
        of: actions,
        matching: find.byType(AnimatedSlide),
      );
      expect(tester.widget<AnimatedSlide>(actionSlide).offset, Offset.zero);

      facade.complete(title: 'Cached title');
      await tester.pump();
      final reveal = find.byType(ComicDetailEntranceReveal);
      expect(
        find.descendant(of: reveal, matching: find.byType(Opacity)),
        findsNothing,
      );
      expect(tester.widget<AnimatedSlide>(actionSlide).offset, Offset.zero);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Windows related covers stay compact within the detail panel', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final details = (await _DesktopDetailFacade().loadComicDetails('related'))
        .copyWith(
          recommend: List.generate(
            18,
            (index) => ExploreComic(
              id: 'related-$index',
              title: 'Related comic $index',
              subTitle: 'Author',
              cover: '',
            ),
          ),
        );
    String? openedComicId;
    for (final width in [1050.0, 520.0]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.windows),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: width,
                child: NestedScrollView(
                  headerSliverBuilder: (context, _) => [
                    SliverOverlapAbsorber(
                      handle: NestedScrollView.sliverOverlapAbsorberHandleFor(
                        context,
                      ),
                      sliver: const SliverToBoxAdapter(
                        child: SizedBox(height: 1),
                      ),
                    ),
                  ],
                  body: ComicDetailRelatedTab(
                    details: details,
                    isActiveInTabView: true,
                    onOpenComic: (comic, _) => openedComicId = comic.id,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final tiles = find.byType(ComicDetailRelatedTile);
      expect(tester.getSize(tiles.first).width, lessThanOrEqualTo(160));
      expect(tester.getSize(tiles.first).width, greaterThan(100));
      expect(
        tester.widgetList<HazukiCachedImage>(find.byType(HazukiCachedImage)),
        everyElement(
          isA<HazukiCachedImage>().having(
            (image) => image.keepInMemory,
            'keepInMemory',
            isTrue,
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    }
    await tester.tap(find.byType(ComicDetailRelatedTile).first);
    await tester.pumpAndSettle();
    expect(openedComicId, 'related-0');
  });
  testWidgets('comic detail page builds without controller wiring crashes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const comic = ExploreComic(
      id: 'comic-id',
      title: 'Hazuki',
      subTitle: 'Smoke',
      cover: '',
    );
    final readerDependencies = _readerDependencies();

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ComicDetailPage(
          comic: comic,
          dependencies: _comicDetailDependencies(),
          heroTag: 'hero',
          readerWidgetBuilder:
              ({
                required title,
                required chapterTitle,
                required comicId,
                required epId,
                required chapterIndex,
                required images,
                required sourceKey,
                coverUrl = '',
                comicTheme,
                onFavoriteRequested,
              }) => ReaderPage(
                title: title,
                chapterTitle: chapterTitle,
                comicId: comicId,
                epId: epId,
                chapterIndex: chapterIndex,
                images: images,
                dependencies: readerDependencies,
                sourceKey: sourceKey,
                coverUrl: coverUrl,
                commentsWidgetBuilder: _buildReaderComments,
              ),
          searchPageBuilder: (_) => const SizedBox.shrink(),
          commentsWidgetBuilder: _buildComments,
        ),
      ),
    );

    expect(find.byType(ComicDetailPage), findsOneWidget);
    expect(find.byType(TabBar), findsOneWidget);
  });

  testWidgets('non-JM detail page hides related tab and like action', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const comic = ExploreComic(
      id: 'copy-comic-id',
      sourceKey: 'copy_manga',
      title: 'Hazuki',
      subTitle: 'Smoke',
      cover: '',
    );
    final readerDependencies = _readerDependencies();

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ComicDetailPage(
          comic: comic,
          dependencies: _comicDetailDependencies(),
          heroTag: 'hero',
          readerWidgetBuilder:
              ({
                required title,
                required chapterTitle,
                required comicId,
                required epId,
                required chapterIndex,
                required images,
                required sourceKey,
                coverUrl = '',
                comicTheme,
                onFavoriteRequested,
              }) => ReaderPage(
                title: title,
                chapterTitle: chapterTitle,
                comicId: comicId,
                epId: epId,
                chapterIndex: chapterIndex,
                images: images,
                dependencies: readerDependencies,
                sourceKey: sourceKey,
                coverUrl: coverUrl,
                commentsWidgetBuilder: _buildReaderComments,
              ),
          searchPageBuilder: (_) => const SizedBox.shrink(),
          commentsWidgetBuilder: _buildComments,
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(ComicDetailPage), findsOneWidget);
    expect(find.byType(Tab), findsNWidgets(2));
    expect(find.text('Related'), findsNothing);
    expect(find.byIcon(Icons.thumb_up_alt_outlined), findsNothing);
    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
  });
}

class _DesktopDetailFacade extends ComicDetailFeatureFacade {
  _DesktopDetailFacade()
    : super(
        source: sl<SourceComicDetailGateway>(),
        local: sl<LocalFavoritesRepository>(),
        downloader: sl<MangaDownloadService>(),
        readingProgress: sl<ReadingProgressService>(),
        readHistory: sl<ReadHistoryService>(),
        sourceKey: 'copy_manga',
      );

  @override
  Future<ComicDetailsData> loadComicDetails(
    String id, {
    String sourceKey = '',
    bool forceRefresh = false,
  }) async => ComicDetailsData(
    id: id,
    sourceKey: 'copy_manga',
    title: 'A long comic title that should wrap naturally on a narrow window',
    subTitle: 'An illustrated journey',
    cover: '',
    description:
        'A quiet town, a mysterious letter, and a journey beyond the familiar.',
    updateTime: '2026-09-10',
    likesCount: '1234',
    chapters: const {'1': 'Chapter 1'},
    tags: const {
      'author': ['Hazuki Studio'],
      'tags': ['Adventure', 'Fantasy'],
    },
    recommend: const [],
    isFavorite: false,
    subId: '',
  );
}

class _CompletingDesktopDetailFacade extends _DesktopDetailFacade {
  final Completer<ComicDetailsData> _completer = Completer<ComicDetailsData>();

  void complete({String title = 'Stable title'}) {
    _completer.complete(
      ComicDetailsData(
        id: 'desktop-loading-reveal',
        sourceKey: 'copy_manga',
        title: title,
        subTitle: 'Stable subtitle',
        cover: '',
        description: 'Resolved summary',
        updateTime: '2026-09-11',
        likesCount: '42',
        chapters: {'1': 'Chapter 1'},
        tags: {
          'author': ['Hazuki Studio'],
        },
        recommend: [],
        isFavorite: false,
        subId: '',
      ),
    );
  }

  @override
  Future<ComicDetailsData> loadComicDetails(
    String id, {
    String sourceKey = '',
    bool forceRefresh = false,
  }) => _completer.future;
}

Widget _buildDesktopTestDetail({
  required ExploreComic comic,
  required ComicDetailFeatureFacade facade,
  bool? shouldAnimateInitialRevealOverride,
}) {
  return ComicDetailPage(
    comic: comic,
    dependencies: _comicDetailDependencies(),
    repository: facade,
    heroTag: 'test-${comic.id}',
    shouldAnimateInitialRevealOverride: shouldAnimateInitialRevealOverride,
    readerWidgetBuilder:
        ({
          required title,
          required chapterTitle,
          required comicId,
          required epId,
          required chapterIndex,
          required images,
          required sourceKey,
          coverUrl = '',
          comicTheme,
          onFavoriteRequested,
        }) => const SizedBox.shrink(),
    searchPageBuilder: (_) => const SizedBox.shrink(),
    commentsWidgetBuilder: _buildComments,
  );
}
