import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hazuki/features/comic_detail/view/comic_detail_meta.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/models/hazuki_models.dart';

void main() {
  testWidgets('detail authors and tags use category-aware tag callback', (
    tester,
  ) async {
    final pressedValues = <String>[];

    const details = ComicDetailsData(
      id: '123',
      title: 'Hazuki',
      subTitle: '',
      cover: '',
      description: '',
      updateTime: '',
      likesCount: '',
      chapters: <String, String>{},
      tags: <String, List<String>>{
        'author': <String>['Artist'],
        'tags': <String>['Action'],
        'views': <String>['10'],
      },
      recommend: <ExploreComic>[],
      isFavorite: false,
      subId: '',
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ComicDetailMetaSection(
            details: details,
            onCopyId: (_) {},
            onTagValuePressed: pressedValues.add,
            onMetaValueLongPress: (_) {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('Artist'));
    await tester.tap(find.text('Action'));

    expect(pressedValues, <String>['Artist', 'Action']);
  });

  testWidgets('picacg detail separates categories tags and uploader', (
    tester,
  ) async {
    const details = ComicDetailsData(
      id: 'picacg-id',
      title: 'Hazuki',
      subTitle: '',
      cover: '',
      description: '',
      updateTime: '',
      likesCount: '',
      chapters: <String, String>{},
      tags: <String, List<String>>{
        'Author': <String>['Artist'],
        'Categories': <String>['Webtoon'],
        'Tags': <String>['Action'],
        'Chinese Team': <String>['Team A'],
      },
      recommend: <ExploreComic>[],
      isFavorite: false,
      subId: '',
      uploader: 'Uploader',
      sourceKey: 'picacg',
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ComicDetailMetaSection(
            details: details,
            showComicId: false,
            onCopyId: (_) {},
            onTagValuePressed: (_) {},
            onMetaValueLongPress: (_) {},
          ),
        ),
      ),
    );

    expect(find.textContaining('ID:'), findsNothing);
    expect(find.text('Categories: '), findsOneWidget);
    expect(find.text('Webtoon'), findsOneWidget);
    expect(find.text('Tags: '), findsOneWidget);
    expect(find.text('Action'), findsOneWidget);
    expect(find.text('Uploader: '), findsOneWidget);
    expect(find.text('Uploader'), findsOneWidget);
    expect(find.text('Chinese team: '), findsOneWidget);
    expect(find.text('Team A'), findsOneWidget);
  });

  testWidgets('jm detail separates tags works and actors', (tester) async {
    final pressedValues = <String>[];

    const details = ComicDetailsData(
      id: '123',
      title: 'Hazuki',
      subTitle: '',
      cover: '',
      description: '',
      updateTime: '',
      likesCount: '',
      chapters: <String, String>{},
      tags: <String, List<String>>{
        'Author': <String>['Artist'],
        'Tag': <String>['Action'],
        'Work': <String>['Original'],
        'Actor': <String>['Heroine'],
        'View': <String>['10'],
      },
      recommend: <ExploreComic>[],
      isFavorite: false,
      subId: '',
      sourceKey: 'jm',
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ComicDetailMetaSection(
            details: details,
            onCopyId: (_) {},
            onTagValuePressed: pressedValues.add,
            onMetaValueLongPress: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Tags: '), findsOneWidget);
    expect(find.text('Action'), findsOneWidget);
    expect(find.text('\u4f5c\u54c1: '), findsOneWidget);
    expect(find.text('Original'), findsOneWidget);
    expect(find.text('\u89d2\u8272: '), findsOneWidget);
    expect(find.text('Heroine'), findsOneWidget);

    await tester.tap(find.text('Action'));
    await tester.tap(find.text('Original'));
    await tester.tap(find.text('Heroine'));

    expect(pressedValues, <String>['Action', 'Original', 'Heroine']);
  });
}
