import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/features/comic_detail/view/comic_detail_page.dart';
import 'package:hazuki/features/reader/view/reader_page.dart';
import 'package:hazuki/models/hazuki_models.dart';

void main() {
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
              ),
          searchPageBuilder: (_) => const SizedBox.shrink(),
        ),
      ),
    );

    expect(find.byType(ComicDetailPage), findsOneWidget);
    expect(find.byType(TabBar), findsOneWidget);
  });
}
