import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/features/comic_detail/view/comic_detail_page.dart';
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
import '../../support/test_service_locator.dart';

Widget _buildComments({
  required String comicId,
  String? subId,
  required String sourceKey,
  ScrollController? scrollController,
  Future<void> Function()? onRequestTabFullscreen,
  bool showAppBar = false,
  bool isTabView = false,
  bool isActiveInTabView = true,
  Map<String, Object?> Function()? debugOuterScrollStateBuilder,
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
    await ensureTestServiceLocator();
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
