import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/features/comic_detail/view/comic_detail_page.dart';
import 'package:hazuki/features/reader/view/reader_page.dart';
import 'package:hazuki/models/hazuki_models.dart';
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

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ComicDetailPage(
          comic: comic,
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

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ComicDetailPage(
          comic: comic,
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
