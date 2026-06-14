import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/downloads/view/downloaded_comic_detail_widgets.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/services/manga_download/manga_download_models.dart';

void main() {
  testWidgets('description over four lines expands fully and collapses', (
    tester,
  ) async {
    const description = 'Line 1\nLine 2\nLine 3\nLine 4\nLine 5\nLine 6';

    await tester.pumpWidget(_wrapDescription(description));

    final textFinder = find.byKey(
      const ValueKey<String>('downloaded_description_text'),
    );
    final sizeFinder = find.byKey(
      const ValueKey<String>('downloaded_description_size'),
    );
    final toggleFinder = find.byKey(
      const ValueKey<String>('downloaded_description_toggle'),
    );
    final collapsedHeight = tester.getSize(sizeFinder).height;
    var text = tester.widget<Text>(textFinder);

    expect(text.maxLines, 4);
    expect(text.overflow, TextOverflow.ellipsis);
    expect(toggleFinder, findsOneWidget);

    await tester.tap(toggleFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 140));

    final expandingHeight = tester.getSize(sizeFinder).height;
    expect(expandingHeight, greaterThan(collapsedHeight));

    await tester.pumpAndSettle();
    text = tester.widget<Text>(textFinder);
    final expandedHeight = tester.getSize(sizeFinder).height;

    expect(text.data, description);
    expect(text.maxLines, isNull);
    expect(text.overflow, TextOverflow.visible);
    expect(expandedHeight, greaterThan(collapsedHeight));

    await tester.tap(toggleFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 140));

    expect(tester.getSize(sizeFinder).height, lessThan(expandedHeight));

    await tester.pumpAndSettle();
    text = tester.widget<Text>(textFinder);

    expect(text.maxLines, 4);
    expect(tester.getSize(sizeFinder).height, collapsedHeight);
  });

  testWidgets('description with four lines does not show a toggle', (
    tester,
  ) async {
    await tester.pumpWidget(_wrapDescription('Line 1\nLine 2\nLine 3\nLine 4'));

    expect(
      find.byKey(const ValueKey<String>('downloaded_description_toggle')),
      findsNothing,
    );
  });

  testWidgets('overview and metadata show offline comic details', (
    tester,
  ) async {
    const comic = DownloadedMangaComic(
      comicId: 'comic-123',
      sourceKey: 'jm',
      title: 'Hazuki',
      subTitle: 'Subtitle',
      description: '',
      coverUrl: '',
      tags: {
        '作者': ['Author A'],
        '标签': ['Tag A', 'Tag B'],
      },
      uploader: 'Uploader A',
      updateTime: '2026-06-14',
      pageCount: '128',
      localCoverPath: null,
      chapters: [],
      updatedAtMillis: 1,
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ListView(
            children: [
              DownloadedComicOverviewCard(
                comic: comic,
                imageCount: 20,
                coverHeroTag: 'cover',
                onCoverTap: () {},
                onCopyId: () {},
              ),
              DownloadedComicMetadata(
                tags: comic.tags,
                uploader: comic.uploader,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('ID: comic-123'), findsOneWidget);
    expect(find.text('Author A'), findsOneWidget);
    expect(find.text('Tag A'), findsOneWidget);
    expect(find.text('Tag B'), findsOneWidget);
    expect(find.text('Uploader A'), findsOneWidget);
    expect(find.textContaining('2026-06-14'), findsOneWidget);
  });
}

Widget _wrapDescription(String text) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 240,
          child: DownloadedComicExpandableDescription(text: text),
        ),
      ),
    ),
  );
}
