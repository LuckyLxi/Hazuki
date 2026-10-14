import '../../support/source_presentation_fixtures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hazuki/features/comic_detail/view/comic_detail_meta.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/source/source_capabilities.dart';

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
        builder: (context, child) => withTestSourcePresentation(child!),
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
        builder: (context, child) => withTestSourcePresentation(child!),
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
        builder: (context, child) => withTestSourcePresentation(child!),
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

  for (final spec in [
    (
      name: 'uploader does not enable other explicitly disabled fields',
      presentation: <String, dynamic>{
        'showUploader': true,
        'showCategories': false,
        'showChineseTeam': false,
        'detailTagGroups': ['Genre'],
      },
      categories: false,
      team: false,
      uploader: true,
      tags: <String>['Fantasy'],
    ),
    (
      name: 'categories and team work without uploader',
      presentation: <String, dynamic>{
        'showUploader': false,
        'showCategories': true,
        'showChineseTeam': true,
        'detailTagGroups': ['tags'],
      },
      categories: true,
      team: true,
      uploader: false,
      tags: <String>['Action'],
    ),
    (
      name: 'empty tag groups hide tags with uploader enabled',
      presentation: <String, dynamic>{
        'showUploader': true,
        'showCategories': false,
        'showChineseTeam': false,
        'detailTagGroups': <String>[],
      },
      categories: false,
      team: false,
      uploader: true,
      tags: <String>[],
    ),
    (
      name: 'legacy declarations preserve existing metadata rows',
      presentation: <String, dynamic>{'showUploader': true},
      categories: true,
      team: true,
      uploader: true,
      tags: <String>['Action'],
    ),
    (
      name: 'detail tag groups ignore whitespace and case',
      presentation: <String, dynamic>{
        'showCategories': false,
        'showChineseTeam': false,
        'detailTagGroups': [' GENRE '],
      },
      categories: false,
      team: false,
      uploader: false,
      tags: <String>['Fantasy'],
    ),
  ]) {
    testWidgets(spec.name, (tester) async {
      const details = ComicDetailsData(
        id: 'custom-id',
        title: 'Comic',
        subTitle: '',
        cover: '',
        description: '',
        updateTime: '',
        likesCount: '',
        chapters: {},
        tags: {
          'Author': ['Artist'],
          'Categories': ['Webtoon'],
          'Tags': ['Action'],
          'Chinese Team': ['Team A'],
          'Genre': ['Fantasy'],
          'Views': ['10'],
        },
        recommend: [],
        isFavorite: false,
        subId: '',
        uploader: 'Uploader',
        sourceKey: 'arbitrary',
      );
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          builder: (context, child) => withTestSourcePresentation(
            child!,
            activeSourceKey: 'arbitrary',
            catalog: [
              SourceCatalogEntry(
                key: 'arbitrary',
                name: 'Custom',
                fileName: 'main.js',
                presentation: spec.presentation,
              ),
            ],
          ),
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
      expect(
        find.text('Categories: '),
        spec.categories ? findsOneWidget : findsNothing,
      );
      expect(
        find.text('Chinese team: '),
        spec.team ? findsOneWidget : findsNothing,
      );
      expect(
        find.text('Uploader: '),
        spec.uploader ? findsOneWidget : findsNothing,
      );
      final tags = tester
          .widgetList<ComicDetailMetaRow>(find.byType(ComicDetailMetaRow))
          .singleWhere((row) => row.label == 'Tags');
      expect(tags.values, spec.tags);
      expect(find.textContaining('ID:'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
