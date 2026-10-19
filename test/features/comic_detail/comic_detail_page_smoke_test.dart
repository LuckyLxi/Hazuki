import '../../support/source_presentation_fixtures.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/features/comic_detail/view/comic_detail_page.dart';
import 'package:hazuki/features/comic_detail/view/comic_detail_header.dart';
import 'package:hazuki/features/comic_detail/view/comic_detail_header_favorite_row.dart';
import 'package:hazuki/features/comic_detail/view/comic_detail_header_cover.dart';
import 'package:hazuki/features/comic_detail/view/comic_detail_header_action_row.dart';
import 'package:hazuki/features/comic_detail/view/comic_detail_favorite_button.dart';
import 'package:hazuki/features/comic_detail/view/comic_detail_related_tab.dart';
import 'package:hazuki/features/comic_detail/view/comic_detail_related_tile.dart';
import 'package:hazuki/features/comic_detail/view/comic_detail_meta.dart';
import 'package:hazuki/features/comic_detail/view/comic_detail_expandable_description.dart';
import 'package:hazuki/features/comic_detail/view/comic_detail_view_primitives.dart';
import 'package:hazuki/features/comic_detail/repository/comic_detail_repository.dart';
import 'package:hazuki/features/comic_detail/support/comic_detail_dependencies.dart';
import 'package:hazuki/features/comic_detail/support/comic_detail_reveal_registry.dart';
import 'package:hazuki/features/comic_detail/support/comic_detail_scope.dart';
import 'package:hazuki/features/reader/support/reader_dependencies.dart';
import 'package:hazuki/features/reader/view/reader_page.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/app/service_locator.dart';
import 'package:hazuki/services/manga_download/manga_download_service.dart';
import 'package:hazuki/services/local_favorites/local_favorites_contracts.dart';
import 'package:hazuki/services/read_history_service.dart';
import 'package:hazuki/services/reading_progress_service.dart';
import 'package:hazuki/services/storage/hazuki_database.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/shared/comments/comments_widget_builder.dart';
import 'package:hazuki/shared/comments/comments_interaction_state.dart';
import 'package:hazuki/shared/window/window_title_bar_control.dart';
import 'package:hazuki/shared/reading/reader_settings_store.dart';
import 'package:hazuki/widgets/cached_image_widgets.dart';
import 'package:hazuki/widgets/expanding_chapter_sheet.dart';
import 'package:hazuki/features/comic_detail/view/comic_detail_chapters_panel.dart';
import 'package:hazuki/shared/favorites/favorite_folders_morph_dialog.dart';
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
  for (final platform in [TargetPlatform.android, TargetPlatform.windows]) {
    testWidgets('reader icon moves smoothly as the label shrinks ($platform)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final facade = _MutableReadingProgressDetailFacade();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          locale: const Locale('en'),
          builder: (context, child) => withTestSourcePresentation(child!),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: _buildDesktopTestDetail(
            comic: const ExploreComic(
              id: 'shrinking-progress',
              sourceKey: 'copy_manga',
              title: 'Comic',
              subTitle: '',
              cover: '',
            ),
            facade: facade,
            shouldAnimateInitialRevealOverride: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final icon = find.byIcon(Icons.menu_book_outlined);
      final initialX = tester.getCenter(icon).dx;
      final session = ComicDetailScope.of(
        tester.element(find.byType(ComicDetailHeaderActionRow)),
      ).session;
      facade.progress = null;
      await session.loadReadingProgress();
      await tester.pump();
      expect(tester.getCenter(icon).dx, closeTo(initialX, 0.1));
      await tester.pump(const Duration(milliseconds: 80));
      final middleX = tester.getCenter(icon).dx;
      await tester.pump(const Duration(milliseconds: 120));
      final nearEndX = tester.getCenter(icon).dx;
      await tester.pumpAndSettle();
      final finalX = tester.getCenter(icon).dx;
      expect(middleX, greaterThan(initialX));
      expect(middleX, lessThan(finalX));
      expect(nearEndX, greaterThan(middleX));
      expect(finalX - nearEndX, lessThan((finalX - initialX) * 0.05));
      expect(find.text('Read'), findsOneWidget);
      expect(find.text('Continue reading Chapter 3'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
    testWidgets(
      'reading button updates after a delayed reader exit save ($platform)',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(
          ReaderSettingsStore.windowsShortcutsGuideSeenKey,
          true,
        );
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final titleBar = _NavigationTitleBarControl();
        addTearDown(titleBar.dispose);
        final progress = _DelayedReadingProgressService(
          database: sl<HazukiDatabase>(),
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            locale: const Locale('en'),
            builder: (context, child) => withTestSourcePresentation(
              HazukiWindowsTitleBarScope(controller: titleBar, child: child!),
            ),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ComicDetailPage(
              comic: const ExploreComic(
                id: 'delayed-progress',
                sourceKey: 'copy_manga',
                title: 'Comic',
                subTitle: '',
                cover: '',
              ),
              dependencies: _comicDetailDependencies(),
              repository: _ReadingProgressDetailFacade(),
              heroTag: 'delayed-progress',
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
                  }) => ReaderPage(
                    title: title,
                    chapterTitle: chapterTitle,
                    comicId: comicId,
                    epId: epId,
                    chapterIndex: chapterIndex,
                    images: const [],
                    sourceKey: sourceKey,
                    offlineMode: true,
                    dependencies: ReaderDependencies(
                      sourceReader: sl<SourceReaderGateway>(),
                      sourceSettings: sl<SourceSettingsGateway>(),
                      readingProgressService: progress,
                      downloader: sl<MangaDownloadService>(),
                    ),
                    commentsWidgetBuilder: _buildReaderComments,
                  ),
              searchPageBuilder: (_) => const SizedBox.shrink(),
              commentsWidgetBuilder: _buildComments,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Read'), findsOneWidget);
        await tester.tap(find.byIcon(Icons.format_list_bulleted_rounded));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Chapter 3'));
        await tester.pumpAndSettle();
        final reader = find.byType(ReaderPage);
        expect(reader, findsOneWidget);
        Navigator.of(tester.element(reader)).pop();
        await tester.pumpAndSettle();
        expect(reader, findsNothing);
        expect(find.text('Read'), findsOneWidget);
        final button = find.ancestor(
          of: find.text('Read'),
          matching: find.byType(FilledButton),
        );
        final buttonRect = tester.getRect(button);
        // The route-return refresh has already finished with no saved progress.
        // Commit only now, after the reader has been disposed.
        await tester.runAsync(() async {
          progress.allowSave.complete();
          await progress.saved.future;
        });
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 80));
        expect(find.text('Read'), findsOneWidget);
        final updatedLabel = find.text('Continue reading Chapter 3');
        expect(updatedLabel, findsOneWidget);
        final fade = tester.widget<FadeTransition>(
          find
              .ancestor(of: updatedLabel, matching: find.byType(FadeTransition))
              .first,
        );
        expect(fade.opacity.value, greaterThan(0));
        expect(fade.opacity.value, lessThan(1));
        final slide = tester.widget<SlideTransition>(
          find
              .ancestor(
                of: updatedLabel,
                matching: find.byType(SlideTransition),
              )
              .first,
        );
        expect(slide.position.value.dy, greaterThan(0));
        expect(slide.position.value.dy, lessThan(0.16));
        final animatingButtonRect = tester.getRect(button);
        expect(animatingButtonRect.left, buttonRect.left);
        expect(animatingButtonRect.right, buttonRect.right);
        expect(animatingButtonRect.center, buttonRect.center);
        await tester.pumpAndSettle();
        expect(find.text('Continue reading Chapter 3'), findsOneWidget);
        expect(find.text('Read'), findsNothing);
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        await tester.pumpAndSettle();
        final switcher = tester.widget<AnimatedSwitcher>(
          find
              .ancestor(
                of: updatedLabel,
                matching: find.byType(AnimatedSwitcher),
              )
              .first,
        );
        expect(switcher.duration, Duration.zero);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
    for (final canLike in [false, true]) {
      testWidgets(
        'custom header stats keep order, localization and like behavior ($platform, like=$canLike)',
        (tester) async {
          tester.view.physicalSize = const Size(1200, 1800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final facade = _CompletingLikeDetailFacade()..canLike = canLike;
          final locale = ValueNotifier(const Locale('en'));
          addTearDown(locale.dispose);
          final page = _buildDesktopTestDetail(
            comic: const ExploreComic(
              id: 'custom-stats',
              sourceKey: 'copy_manga',
              title: 'Comic',
              subTitle: '',
              cover: '',
            ),
            facade: facade,
            shouldAnimateInitialRevealOverride: false,
          );
          await tester.pumpWidget(
            ValueListenableBuilder<Locale>(
              valueListenable: locale,
              builder: (_, value, child) => MaterialApp(
                locale: value,
                theme: ThemeData(platform: platform),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: page,
              ),
            ),
          );
          facade.complete(
            headerStats: const [
              ComicHeaderStat(text: {'zh': '评分9.8', 'en': 'Rating 9.8'}),
              ComicHeaderStat(text: ''),
              ComicHeaderStat(
                text: {'zh': '自定义点赞', 'en': 'Custom likes'},
                action: ComicHeaderStatAction.like,
              ),
              ComicHeaderStat(text: {'zh': '每周更新', 'en': 'Weekly'}),
            ],
          );
          await tester.pumpAndSettle();
          final row = find.byType(ComicDetailHeaderFavoriteRow);
          final desktop = platform == TargetPlatform.windows;
          if (desktop) {
            expect(
              find.descendant(
                of: row,
                matching: find.text('Rating 9.8 / Custom likes / Weekly'),
              ),
              findsOneWidget,
            );
          } else if (canLike) {
            expect(
              tester.getTopLeft(find.text('Rating 9.8')).dx,
              lessThan(tester.getTopLeft(find.text('Custom likes')).dx),
            );
            expect(
              tester.getTopLeft(find.text('Custom likes')).dx,
              lessThan(tester.getTopLeft(find.text('Weekly')).dx),
            );
            await tester.tap(find.text('Custom likes'));
            await tester.pumpAndSettle();
            expect(facade.likeCalls, [
              ('desktop-loading-reveal', true, 'copy_manga'),
            ]);
            expect(find.byIcon(Icons.thumb_up_alt_rounded), findsOneWidget);
          } else {
            expect(
              find.descendant(
                of: row,
                matching: find.text('Rating 9.8 · Custom likes · Weekly'),
              ),
              findsOneWidget,
            );
            expect(find.byIcon(Icons.thumb_up_alt_outlined), findsNothing);
            expect(facade.likeCalls, isEmpty);
          }
          expect(find.text('42 likes'), findsNothing);
          locale.value = const Locale('zh', 'CN');
          await tester.pumpAndSettle();
          expect(
            find.descendant(of: row, matching: find.textContaining('评分9.8')),
            findsOneWidget,
          );
          expect(
            find.descendant(of: row, matching: find.textContaining('每周更新')),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          await tester.pump(const Duration(seconds: 4));
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
    testWidgets(
      'empty header stats do not fall back to old counts ($platform)',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 1800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final facade = _CompletingLikeDetailFacade()..canLike = true;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: _buildDesktopTestDetail(
              comic: const ExploreComic(
                id: 'no-stats',
                sourceKey: 'copy_manga',
                title: 'Comic',
                subTitle: '',
                cover: '',
              ),
              facade: facade,
              shouldAnimateInitialRevealOverride: false,
            ),
          ),
        );
        facade.complete(headerStats: []);
        await tester.pumpAndSettle();
        expect(find.text('42 likes'), findsNothing);
        expect(
          find.byIcon(Icons.thumb_up_alt_outlined),
          platform == TargetPlatform.windows ? findsOneWidget : findsNothing,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  for (final declaration in [null, false, true]) {
    for (final related in [false, true]) {
      testWidgets(
        'comment declaration=$declaration and related=$related compose tabs',
        (tester) async {
          tester.view.physicalSize = const Size(1200, 1800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            MaterialApp(
              locale: const Locale('en'),
              builder: (context, child) => withTestSourcePresentation(
                child!,
                activeSourceKey: 'copy_manga',
                catalog: [
                  SourceCatalogEntry(
                    key: 'copy_manga',
                    name: 'Custom',
                    fileName: 'main.js',
                    presentation: {
                      'showComments': ?declaration,
                      'buttons': [
                        if (related)
                          {
                            'id': 'relatedComics',
                            'location': 'comicDetailTabs',
                          },
                      ],
                    },
                  ),
                ],
              ),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: _buildDesktopTestDetail(
                comic: const ExploreComic(
                  id: 'comments-contract',
                  sourceKey: 'copy_manga',
                  title: 'Comic',
                  subTitle: '',
                  cover: '',
                ),
                facade: _DesktopDetailFacade(),
                shouldAnimateInitialRevealOverride: false,
                initialTabIndex: 99,
              ),
            ),
          );
          await tester.pumpAndSettle();
          final comments = declaration == true;
          final tabs = tester.widget<TabBar>(find.byType(TabBar));
          expect(tabs.tabs.length, 1 + (comments ? 1 : 0) + (related ? 1 : 0));
          expect(
            find.text('Comments'),
            comments ? findsOneWidget : findsNothing,
          );
          expect(tabs.controller!.index, tabs.tabs.length - 1);
          if (related) {
            await tester.tap(find.text('Related'));
            await tester.pumpAndSettle();
            expect(
              tester
                  .widget<ComicDetailRelatedTab>(
                    find.byType(ComicDetailRelatedTab),
                  )
                  .isActiveInTabView,
              isTrue,
            );
            expect(tabs.controller!.index, comments ? 2 : 1);
          }
          await tester.tap(find.byType(Tab).first);
          await tester.pumpAndSettle();
          expect(find.byType(ComicDetailMetaSection), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
  for (final platform in [TargetPlatform.android, TargetPlatform.windows]) {
    testWidgets(
      'authors stay in plugin info rows before and after loading in $platform',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 2200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final facade = _CompletingDesktopDetailFacade();
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            builder: (context, child) => withTestSourcePresentation(child!),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: _buildDesktopTestDetail(
              comic: const ExploreComic(
                id: 'author-tags-only',
                sourceKey: 'copy_manga',
                title: 'Comic',
                subTitle: 'Hazuki Studio',
                cover: '',
              ),
              facade: facade,
              shouldAnimateInitialRevealOverride: false,
            ),
          ),
        );
        await tester.pump();
        expect(find.text('Hazuki Studio'), findsNothing);

        facade.complete(subTitle: 'Hazuki Studio');
        await tester.pumpAndSettle();
        final header = find.byType(ComicDetailHeaderSection);
        expect(
          find.descendant(of: header, matching: find.text('Hazuki Studio')),
          findsNothing,
        );
        final author = find.widgetWithText(ActionChip, 'Hazuki Studio');
        expect(author, findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(ComicDetailMetaSection),
            matching: author,
          ),
          findsOneWidget,
        );
        if (platform == TargetPlatform.windows) {
          tester.view.physicalSize = const Size(560, 1000);
          await tester.pumpAndSettle();
          expect(
            find.descendant(of: header, matching: find.text('Hazuki Studio')),
            findsNothing,
          );
          expect(author, findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      'like button follows the initialized plugin capability in $platform',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 2200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final facade = _CompletingLikeDetailFacade();
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: _buildDesktopTestDetail(
              comic: const ExploreComic(
                id: 'like-capability',
                sourceKey: 'copy_manga',
                title: 'Comic',
                subTitle: '',
                cover: '',
              ),
              facade: facade,
              shouldAnimateInitialRevealOverride: false,
            ),
          ),
        );
        await tester.pump();
        expect(find.byIcon(Icons.thumb_up_alt_outlined), findsNothing);
        facade.canLike = true;
        facade.complete();
        await tester.pumpAndSettle();
        final like = find.byIcon(Icons.thumb_up_alt_outlined);
        expect(like, findsOneWidget);
        await tester.tap(like);
        await tester.pumpAndSettle();
        expect(facade.likeCalls, [
          ('desktop-loading-reveal', true, 'copy_manga'),
        ]);
        expect(find.byIcon(Icons.thumb_up_alt_rounded), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();
      },
    );
  }
  for (final openReader in [true, false]) {
    testWidgets('mobile detail uses horizontal routing for '
        '${openReader ? 'reader' : 'tag search'}', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final titleBar = _NavigationTitleBarControl();
      addTearDown(titleBar.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.android),
          builder: (context, child) => withTestSourcePresentation(
            HazukiWindowsTitleBarScope(controller: titleBar, child: child!),
          ),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ComicDetailPage(
            comic: const ExploreComic(
              id: 'mobile-navigation',
              sourceKey: 'copy_manga',
              title: 'Comic',
              subTitle: '',
              cover: '',
            ),
            dependencies: _comicDetailDependencies(),
            repository: _NavigationDetailFacade(),
            heroTag: 'mobile-navigation',
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
            searchPageBuilder: (keyword) =>
                Scaffold(body: Text('Search destination: $keyword')),
            commentsWidgetBuilder: _buildComments,
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (openReader) {
        await tester.tap(find.byIcon(Icons.menu_book_outlined));
      } else {
        final author = find.text('Hazuki Studio');
        await tester.ensureVisible(author);
        await tester.pumpAndSettle();
        await tester.tap(author);
      }
      await tester.pumpAndSettle();
      final destination = find.text(
        openReader ? 'Reader destination' : 'Search destination: Hazuki Studio',
      );
      expect(destination, findsOneWidget);
      expect(
        ModalRoute.of(tester.element(destination)),
        isA<CupertinoPageRoute<void>>(),
      );
      Navigator.of(tester.element(destination)).pop();
      await tester.pumpAndSettle();
      expect(find.byType(ComicDetailPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final platform in [TargetPlatform.android, TargetPlatform.windows]) {
    for (final disableAnimations in [false, true]) {
      testWidgets(
        'chapter sheet expands into reader ($platform, reduced=$disableAnimations)',
        (tester) async {
          tester.view.physicalSize = platform == TargetPlatform.android
              ? const Size(390, 844)
              : const Size(1200, 900);
          tester.view.devicePixelRatio = 1;
          tester.view.padding = const FakeViewPadding(top: 24);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPadding);
          final titleBar = _NavigationTitleBarControl();
          addTearDown(titleBar.dispose);
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(platform: platform),
              locale: const Locale('en'),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(disableAnimations: disableAnimations),
                child: withTestSourcePresentation(
                  HazukiWindowsTitleBarScope(
                    controller: titleBar,
                    child: child!,
                  ),
                ),
              ),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: ComicDetailPage(
                comic: const ExploreComic(
                  id: 'chapter-expansion',
                  sourceKey: 'copy_manga',
                  title: 'Comic',
                  subTitle: '',
                  cover: '',
                ),
                dependencies: _comicDetailDependencies(),
                repository: _NavigationDetailFacade(),
                heroTag: 'chapter-expansion',
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
                    }) => Scaffold(
                      body: Text('Reader: $epId $chapterTitle $chapterIndex'),
                    ),
                searchPageBuilder: (_) => const SizedBox.shrink(),
                commentsWidgetBuilder: _buildComments,
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byIcon(Icons.format_list_bulleted_rounded));
          await tester.pumpAndSettle();
          final sheet = find.byType(ExpandingChapterSheet);
          final initialRect = tester.getRect(sheet);
          expect(initialRect.top, greaterThan(24));
          await tester.tap(find.text('Chapter 1'));
          await tester.pump();
          if (!disableAnimations) {
            // A repeated selection during expansion must not open two readers.
            tester
                .widget<ComicDetailChaptersPanel>(
                  find.byType(ComicDetailChaptersPanel),
                )
                .onChapterTap('1', 'Chapter 1', 0);
            await tester.pump(const Duration(milliseconds: 180));
            final expandingRect = tester.getRect(sheet);
            expect(expandingRect.top, lessThan(initialRect.top));
            expect(expandingRect.bottom, closeTo(initialRect.bottom, 0.1));
            expect(expandingRect.height, greaterThan(initialRect.height));
            if (platform == TargetPlatform.windows) {
              expect(expandingRect.width, greaterThan(initialRect.width));
            }
            expect(find.text('Reader: 1 Chapter 1 0'), findsNothing);
          }
          await tester.pumpAndSettle();
          final reader = find.text('Reader: 1 Chapter 1 0');
          expect(reader, findsOneWidget);
          expect(sheet, findsNothing);
          final route = ModalRoute.of(tester.element(reader))!;
          expect(route.animation!.status, AnimationStatus.completed);
          Navigator.of(tester.element(reader)).pop();
          await tester.pumpAndSettle();
          expect(find.byType(ComicDetailPage), findsOneWidget);
          expect(sheet, findsNothing);
          expect(tester.takeException(), isNull);
          if (!disableAnimations) {
            // Removing the sheet during expansion cancels the pending handoff.
            await tester.tap(find.byIcon(Icons.format_list_bulleted_rounded));
            await tester.pumpAndSettle();
            final sheetContext = tester.element(
              find.byType(ComicDetailChaptersPanel),
            );
            final sheetRoute = ModalRoute.of(sheetContext)!;
            final navigator = Navigator.of(sheetContext);
            await tester.tap(find.text('Chapter 1'));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 120));
            navigator.removeRoute(sheetRoute);
            await tester.pumpAndSettle();
            expect(reader, findsNothing);
            expect(sheet, findsNothing);
            expect(find.byType(ComicDetailPage), findsOneWidget);
            expect(tester.takeException(), isNull);
          }
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        },
      );
    }
  }

  testWidgets('mobile first reveal fades without moving content', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final facade = _CompletingDesktopDetailFacade();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.android),
        builder: (context, child) => withTestSourcePresentation(child!),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: _buildDesktopTestDetail(
          comic: const ExploreComic(
            id: 'mobile-first-reveal',
            sourceKey: 'copy_manga',
            title: 'Stable title',
            subTitle: 'Stable subtitle',
            cover: '',
          ),
          facade: facade,
          shouldAnimateInitialRevealOverride: true,
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
    expect(tester.widget<AnimatedSlide>(actionSlide).duration, Duration.zero);
    facade.complete();
    await tester.pump();
    await tester.pump();
    final summary = find.byType(ComicDetailExpandableDescription);
    final resolvedActionTop = tester.getTopLeft(actions).dy;
    final resolvedTabTop = tester.getTopLeft(find.byType(TabBar)).dy;
    final summaryTop = tester.getTopLeft(summary).dy;
    final reveal = find.ancestor(
      of: summary,
      matching: find.byType(ComicDetailEntranceReveal),
    );
    final opacity = find.descendant(of: reveal, matching: find.byType(Opacity));
    expect(tester.widget<Opacity>(opacity).opacity, 0);
    for (final entrance in tester.widgetList<ComicDetailEntranceReveal>(
      find.byType(ComicDetailEntranceReveal),
    )) {
      expect(entrance.beginOffset, Offset.zero);
    }
    await tester.pump(const Duration(milliseconds: 160));
    expect(tester.widget<Opacity>(opacity).opacity, inExclusiveRange(0, 1));
    expect(tester.getTopLeft(summary).dy, closeTo(summaryTop, 0.5));
    expect(tester.getTopLeft(actions).dy, closeTo(resolvedActionTop, 0.5));
    expect(
      tester.getTopLeft(find.byType(TabBar)).dy,
      closeTo(resolvedTabTop, 0.5),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<Opacity>(opacity).opacity, 1);
    expect(tester.getTopLeft(summary).dy, closeTo(summaryTop, 0.5));
    expect(tester.getTopLeft(actions).dy, closeTo(resolvedActionTop, 0.5));
    expect(
      tester.getTopLeft(find.byType(TabBar)).dy,
      closeTo(resolvedTabTop, 0.5),
    );
    expect(tester.takeException(), isNull);
  });

  for (final (canLike, likesCount, textScale, width) in [
    (false, '42', 1.0, 390.0),
    (true, '42', 1.0, 390.0),
    (false, '', 1.0, 390.0),
    (false, '12345678901234567890', 2.0, 320.0),
    (true, '12345678901234567890', 2.0, 320.0),
  ]) {
    testWidgets('Android keeps controls stable from loading to resolved stats '
        '(like: $canLike, count: $likesCount, scale: $textScale)', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final facade = _CompletingLikeDetailFacade();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.android),
          builder: (context, child) => withTestSourcePresentation(
            MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
          ),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: _buildDesktopTestDetail(
            comic: const ExploreComic(
              id: 'android-stable-stats',
              sourceKey: 'copy_manga',
              title: 'Stable title',
              subTitle: 'Stable subtitle',
              cover: '',
            ),
            facade: facade,
            shouldAnimateInitialRevealOverride: true,
          ),
        ),
      );
      await tester.pump();
      final actions = find.byType(ComicDetailHeaderActionRow);
      final tabs = find.byType(TabBar);
      final loadingActionTop = tester.getTopLeft(actions).dy;
      final loadingTabTop = tester.getTopLeft(tabs).dy;
      // Plugin capabilities can become available with the detail response.
      facade.canLike = canLike;
      facade.complete(likesCount: likesCount);
      await tester.pump();
      await tester.pump();
      for (final duration in [
        Duration.zero,
        const Duration(milliseconds: 160),
        const Duration(milliseconds: 200),
      ]) {
        await tester.pump(duration);
        expect(tester.getTopLeft(actions).dy, closeTo(loadingActionTop, 0.5));
        expect(tester.getTopLeft(tabs).dy, closeTo(loadingTabTop, 0.5));
        expect(tester.takeException(), isNull);
      }
      expect(
        find.byIcon(Icons.thumb_up_alt_outlined),
        canLike ? findsOneWidget : findsNothing,
      );
    });
  }

  testWidgets('mobile action bar preserves favorite and chapter dialogs', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final facade = _CompletingMobileDetailFacade();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.android),
        builder: (context, child) => withTestSourcePresentation(child!),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: _buildDesktopTestDetail(
          comic: const ExploreComic(
            id: 'mobile-controls',
            sourceKey: 'copy_manga',
            title: 'Comic',
            subTitle: '',
            cover: '',
          ),
          facade: facade,
          shouldAnimateInitialRevealOverride: false,
        ),
      ),
    );
    await tester.pump();
    final favorite = find.ancestor(
      of: find.byIcon(Icons.favorite_border),
      matching: find.byType(IconButton),
    );
    expect(tester.widget<IconButton>(favorite).onPressed, isNull);
    facade.complete();
    await tester.pumpAndSettle();
    expect(tester.widget<IconButton>(favorite).onPressed, isNotNull);
    final sourceRect = tester.getRect(favorite);
    final buttonOpacity = find.descendant(
      of: find.byType(ComicDetailFavoriteButton),
      matching: find.byType(Opacity),
    );
    await tester.tap(favorite);
    await tester.pump();
    final surface = find.byKey(const ValueKey('favorite-dialog-surface'));
    expect(tester.getRect(surface).left, closeTo(sourceRect.left, 0.5));
    expect(tester.getRect(surface).top, closeTo(sourceRect.top, 0.5));
    expect(tester.getRect(surface).width, closeTo(sourceRect.width, 0.5));
    expect(tester.getRect(surface).height, closeTo(sourceRect.height, 0.5));
    expect(tester.widget<Opacity>(buttonOpacity).opacity, 0);
    await tester.pump(const Duration(milliseconds: 120));
    final openingRect = tester.getRect(surface);
    expect(openingRect.width, greaterThan(sourceRect.width));
    expect(openingRect.center.dx, lessThan(sourceRect.center.dx));
    await tester.pumpAndSettle();
    expect(find.byType(FavoriteFoldersMorphDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
    final expandedRect = tester.getRect(surface);
    expect(expandedRect.width, greaterThan(openingRect.width));
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 160));
    expect(tester.getRect(surface).width, lessThan(expandedRect.width));
    expect(tester.widget<Opacity>(buttonOpacity).opacity, 0);
    await tester.pump(const Duration(milliseconds: 390));
    expect(tester.getRect(surface).left, closeTo(sourceRect.left, 1));
    expect(tester.getRect(surface).top, closeTo(sourceRect.top, 1));
    expect(tester.getRect(surface).width, closeTo(sourceRect.width, 1));
    expect(tester.getRect(surface).height, closeTo(sourceRect.height, 1));
    expect(tester.widget<Opacity>(buttonOpacity).opacity, 0);
    await tester.pumpAndSettle();
    expect(find.byType(FavoriteFoldersMorphDialog), findsNothing);
    expect(tester.widget<Opacity>(buttonOpacity).opacity, 1);
    await tester.tap(find.byIcon(Icons.format_list_bulleted_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(ComicDetailChaptersPanel), findsOneWidget);
    expect(find.text('Chapter 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
  });

  testWidgets('favorite morph hands its button back in the closing frame', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final facade = _MorphDismissalDetailFacade();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.android),
        builder: (context, child) => withTestSourcePresentation(child!),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: _buildDesktopTestDetail(
          comic: const ExploreComic(
            id: 'morph-handoff',
            sourceKey: 'copy_manga',
            title: 'Comic',
            subTitle: '',
            cover: '',
          ),
          facade: facade,
          shouldAnimateInitialRevealOverride: false,
        ),
      ),
    );
    facade.complete();
    await tester.pumpAndSettle();
    final button = find.byType(ComicDetailFavoriteButton);
    final buttonOpacity = find.descendant(
      of: button,
      matching: find.byType(Opacity),
    );
    await tester.tap(button);
    await tester.pumpAndSettle();
    final iconButton = find.descendant(
      of: button,
      matching: find.byType(IconButton),
    );
    expect(tester.widget<IconButton>(iconButton).onPressed, isNotNull);
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump();
    for (var frame = 0; frame < 40; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.widget<IconButton>(iconButton).onPressed, isNotNull);
      if (find.byType(FavoriteFoldersMorphDialog).evaluate().isEmpty) {
        expect(
          tester.renderObject<RenderOpacity>(buttonOpacity).opacity,
          1,
          reason: 'The button must be painted in the frame the overlay leaves.',
        );
      }
    }
    expect(find.byType(FavoriteFoldersMorphDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final closeMethod in ['barrier', 'back', 'save']) {
    testWidgets('favorite morph restores its button after $closeMethod', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final facade = _MorphDismissalDetailFacade();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.android),
          builder: (context, child) => withTestSourcePresentation(child!),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: _buildDesktopTestDetail(
            comic: const ExploreComic(
              id: 'morph-dismissal',
              sourceKey: 'copy_manga',
              title: 'Comic',
              subTitle: '',
              cover: '',
            ),
            facade: facade,
            shouldAnimateInitialRevealOverride: false,
          ),
        ),
      );
      facade.complete();
      await tester.pumpAndSettle();
      final button = find.byType(ComicDetailFavoriteButton);
      final buttonOpacity = find.descendant(
        of: button,
        matching: find.byType(Opacity),
      );
      final sourceRect = tester.getRect(button);
      await tester.tap(button);
      await tester.pump();
      if (closeMethod == 'barrier') {
        // Dismissing during expansion must reverse from the current position.
        await tester.pump(const Duration(milliseconds: 120));
        final surface = find.byKey(const ValueKey('favorite-dialog-surface'));
        final beforeClose = tester.getRect(surface);
        await tester.tapAt(const Offset(10, 10));
        await tester.pump();
        expect(
          tester.getRect(surface),
          rectMoreOrLessEquals(beforeClose, epsilon: 0.000001),
        );
      } else {
        await tester.pumpAndSettle();
        if (closeMethod == 'save') {
          await tester.tap(find.text('Save'));
        } else {
          tester.state<NavigatorState>(find.byType(Navigator)).pop();
        }
        await tester.pump();
      }
      expect(tester.widget<Opacity>(buttonOpacity).opacity, 0);
      await tester.pumpAndSettle();
      expect(find.byType(FavoriteFoldersMorphDialog), findsNothing);
      expect(tester.widget<Opacity>(buttonOpacity).opacity, 1);
      expect(tester.getRect(button), sourceRect);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.byType(FavoriteFoldersMorphDialog), findsOneWidget);
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('favorite morph can close while folders are still loading', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final facade = _SlowMorphDetailFacade();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.android),
        builder: (context, child) => withTestSourcePresentation(child!),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: _buildDesktopTestDetail(
          comic: const ExploreComic(
            id: 'slow-morph',
            sourceKey: 'copy_manga',
            title: 'Comic',
            subTitle: '',
            cover: '',
          ),
          facade: facade,
          shouldAnimateInitialRevealOverride: false,
        ),
      ),
    );
    facade.complete();
    await tester.pumpAndSettle();
    final button = find.byType(ComicDetailFavoriteButton);
    await tester.tap(button);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 480));
    expect(find.byType(FavoriteFoldersMorphDialog), findsOneWidget);
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 480));
    facade.completeFolders();
    await tester.pumpAndSettle();
    expect(find.byType(FavoriteFoldersMorphDialog), findsNothing);
    expect(
      tester
          .widget<Opacity>(
            find.descendant(of: button, matching: find.byType(Opacity)),
          )
          .opacity,
      1,
    );
    expect(tester.takeException(), isNull);
  });

  for (final brightness in Brightness.values) {
    for (final width in [320.0, 390.0, 430.0]) {
      testWidgets('mobile detail fits $width in $brightness with large text', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              platform: TargetPlatform.android,
              brightness: brightness,
            ),
            builder: (context, child) => withTestSourcePresentation(
              MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(1.5)),
                child: child!,
              ),
            ),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: _buildDesktopTestDetail(
              comic: const ExploreComic(
                id: 'mobile-layout',
                sourceKey: 'copy_manga',
                title: 'A long comic title',
                subTitle: 'An illustrated journey',
                cover: '',
              ),
              facade: _DesktopDetailFacade(),
              shouldAnimateInitialRevealOverride: false,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final cover = find.byType(ComicDetailHeaderCover);
        final actions = find.byType(ComicDetailHeaderActionRow);
        expect(tester.getSize(cover).width, inInclusiveRange(88, 135));
        expect(
          tester.getTopLeft(actions).dy,
          greaterThan(tester.getBottomLeft(cover).dy),
        );
        expect(
          tester.widget<ComicDetailHeaderActionRow>(actions).useMobileStyle,
          isTrue,
        );
        final readerButton = find.descendant(
          of: actions,
          matching: find.byType(FilledButton),
        );
        expect(tester.getSize(readerButton).height, greaterThanOrEqualTo(48));
        final chaptersButton = find.descendant(
          of: actions,
          matching: find.byIcon(Icons.format_list_bulleted_rounded),
        );
        final favoriteButton = find.descendant(
          of: actions,
          matching: find.byIcon(Icons.favorite_border),
        );
        expect(find.text('Hazuki Studio'), findsOneWidget);
        expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
        expect(
          tester.getTopRight(readerButton).dx,
          lessThan(tester.getTopLeft(chaptersButton).dx),
        );
        expect(
          tester.getTopRight(chaptersButton).dx,
          lessThan(tester.getTopLeft(favoriteButton).dx),
        );
        await tester.drag(find.byType(NestedScrollView), const Offset(0, -420));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final metadata = find.byType(ComicDetailMetaSection);
        expect(
          tester.widget<ComicDetailMetaSection>(metadata).useMobileStyle,
          isTrue,
        );
        final artist = find.descendant(
          of: metadata,
          matching: find.text('Hazuki Studio'),
        );
        await tester.ensureVisible(artist);
        await tester.pumpAndSettle();
        expect(artist.hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
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
          builder: (context, child) => withTestSourcePresentation(child!),
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
      expect(
        tester.widget<ComicDetailHeaderActionRow>(actions).useMobileStyle,
        isFalse,
      );
      expect(
        tester.widget<ComicDetailMetaSection>(metadata).useMobileStyle,
        isFalse,
      );
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
          builder: (context, child) => withTestSourcePresentation(child!),
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
        builder: (context, child) => withTestSourcePresentation(child!),
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
        builder: (context, child) => withTestSourcePresentation(child!),
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
          builder: (context, child) => withTestSourcePresentation(child!),
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
          builder: (context, child) => withTestSourcePresentation(child!),
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
        builder: (context, child) => withTestSourcePresentation(child!),
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
        builder: (context, child) => withTestSourcePresentation(child!),
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
    expect(find.text('Comments'), findsOneWidget);
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
    headerStats: const [ComicHeaderStat(text: '1234 likes')],
    chapters: const {'1': 'Chapter 1'},
    tags: const {
      'author': ['Hazuki Studio'],
      'tags': ['Adventure', 'Fantasy'],
    },
    infoFields: const [
      ComicInfoField(
        label: 'Author',
        values: ['Hazuki Studio'],
        action: ComicInfoAction.search,
      ),
      ComicInfoField(
        label: 'Tags',
        values: ['Adventure', 'Fantasy'],
        action: ComicInfoAction.search,
      ),
    ],
    recommend: const [],
    isFavorite: false,
    subId: '',
  );
}

class _CompletingDesktopDetailFacade extends _DesktopDetailFacade {
  final Completer<ComicDetailsData> _completer = Completer<ComicDetailsData>();

  void complete({
    String title = 'Stable title',
    String likesCount = '42',
    String subTitle = 'Stable subtitle',
    List<ComicHeaderStat>? headerStats,
  }) {
    _completer.complete(
      ComicDetailsData(
        id: 'desktop-loading-reveal',
        sourceKey: 'copy_manga',
        title: title,
        subTitle: subTitle,
        cover: '',
        description: 'Resolved summary',
        updateTime: '2026-09-11',
        likesCount: likesCount,
        headerStats:
            headerStats ??
            [
              ComicHeaderStat(
                text: likesCount.isEmpty ? 'Like' : '$likesCount likes',
                action: ComicHeaderStatAction.like,
              ),
            ],
        chapters: {'1': 'Chapter 1'},
        tags: {
          'author': ['Hazuki Studio'],
        },
        infoFields: [
          ComicInfoField(
            label: 'Author',
            values: ['Hazuki Studio'],
            action: ComicInfoAction.search,
          ),
        ],
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

class _NavigationDetailFacade extends _DesktopDetailFacade {
  @override
  Future<List<CategoryTagGroup>> loadCategoryTagGroups() async => [];
}

class _ReadingProgressDetailFacade extends _NavigationDetailFacade {
  @override
  Future<ComicDetailsData> loadComicDetails(
    String id, {
    String sourceKey = '',
    bool forceRefresh = false,
  }) async => (await super.loadComicDetails(id)).copyWith(
    chapters: const {'1': 'Chapter 1', '2': 'Chapter 2', '3': 'Chapter 3'},
  );
}

class _MutableReadingProgressDetailFacade extends _ReadingProgressDetailFacade {
  Map<String, dynamic>? progress = {
    'epId': '3',
    'title': 'Chapter 3',
    'index': 2,
  };

  @override
  Future<Map<String, dynamic>?> loadReadingProgress(String comicId) async =>
      progress;
}

class _DelayedReadingProgressService extends ReadingProgressService {
  _DelayedReadingProgressService({required super.database});

  final allowSave = Completer<void>();
  final saved = Completer<void>();

  @override
  Future<void> save({
    required String comicId,
    required String sourceKey,
    required String epId,
    required String title,
    required int chapterIndex,
    required int pageIndex,
  }) async {
    await allowSave.future;
    await super.save(
      comicId: comicId,
      sourceKey: sourceKey,
      epId: epId,
      title: title,
      chapterIndex: chapterIndex,
      pageIndex: pageIndex,
    );
    saved.complete();
  }
}

class _NavigationTitleBarControl extends ChangeNotifier
    implements WindowTitleBarControl {
  @override
  bool get useSystemTitleBar => true;
  @override
  bool get shouldShowCustomTitleBar => false;
  @override
  void suppressCustomTitleBar(Object owner) {}
  @override
  void releaseCustomTitleBarSuppression(Object owner) {}
  @override
  Future<void> updateUseSystemTitleBar(bool value) async {}
}

class _CompletingLikeDetailFacade extends _CompletingDesktopDetailFacade {
  bool canLike = false;
  final likeCalls = <(String, bool, String)>[];
  @override
  bool get supportComicLike => canLike;
  @override
  Future<void> toggleComicLike({
    required String comicId,
    required bool isLike,
    String sourceKey = '',
  }) async {
    likeCalls.add((comicId, isLike, sourceKey));
  }
}

class _CompletingMobileDetailFacade extends _CompletingDesktopDetailFacade {
  @override
  bool get isLogged => false;

  @override
  Future<FavoriteFoldersResult> loadLocalFavoriteFolders({
    required String comicId,
    String sourceKey = '',
  }) async =>
      const FavoriteFoldersResult.success(folders: [], favoritedFolderIds: {});
}

class _MorphDismissalDetailFacade extends _CompletingMobileDetailFacade {
  @override
  Future<FavoriteFoldersResult> loadLocalFavoriteFolders({
    required String comicId,
    String sourceKey = '',
  }) async => const FavoriteFoldersResult.success(
    folders: [
      FavoriteFolder(
        id: 'existing',
        name: 'Local',
        source: FavoriteFolderSource.local,
      ),
    ],
    favoritedFolderIds: {'existing'},
  );
}

class _SlowMorphDetailFacade extends _CompletingMobileDetailFacade {
  final _folders = Completer<FavoriteFoldersResult>();

  void completeFolders() => _folders.complete(
    const FavoriteFoldersResult.success(folders: [], favoritedFolderIds: {}),
  );

  @override
  Future<FavoriteFoldersResult> loadLocalFavoriteFolders({
    required String comicId,
    String sourceKey = '',
  }) => _folders.future;
}

Widget _buildDesktopTestDetail({
  required ExploreComic comic,
  required ComicDetailFeatureFacade facade,
  bool? shouldAnimateInitialRevealOverride,
  int initialTabIndex = 0,
}) {
  return ComicDetailPage(
    comic: comic,
    dependencies: _comicDetailDependencies(),
    repository: facade,
    heroTag: 'test-${comic.id}',
    initialTabIndex: initialTabIndex,
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
