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
import 'package:hazuki/features/comic_detail/repository/comic_detail_repository.dart';
import 'package:hazuki/features/comic_detail/support/comic_detail_dependencies.dart';
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
