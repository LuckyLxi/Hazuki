import '../../support/source_presentation_fixtures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hazuki/features/comic_detail/view/comic_detail_meta.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/source/source_capabilities.dart';

void main() {
  testWidgets('mobile ID precedes authors and copies only on long press', (
    tester,
  ) async {
    final copiedIds = <String>[];
    final pressedTags = <String>[];
    final haptics = <Object?>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            haptics.add(call.arguments);
          }
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });
    const details = ComicDetailsData(
      id: '1433951',
      sourceKey: 'jm',
      title: 'Hazuki',
      subTitle: '',
      cover: '',
      description: '',
      updateTime: '',
      likesCount: '',
      chapters: {},
      tags: {
        'author': ['Artist'],
        'tags': ['Action'],
        'views': ['10'],
      },
      recommend: [],
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
            useMobileStyle: true,
            onCopyId: copiedIds.add,
            onTagValuePressed: pressedTags.add,
            onMetaValueLongPress: (_) {},
          ),
        ),
      ),
    );
    final id = find.text('ID: 1433951');
    expect(id, findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(ComicDetailIdRow),
        matching: find.byType(Chip),
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.copy_all_outlined), findsNothing);
    expect(
      tester.getBottomLeft(find.byType(ComicDetailIdRow)).dy,
      lessThan(tester.getTopLeft(find.text('Artist')).dy),
    );
    await tester.tap(id);
    await tester.pumpAndSettle();
    expect(copiedIds, isEmpty);
    expect(pressedTags, isEmpty);
    expect(haptics, isEmpty);
    await tester.longPress(id);
    await tester.pumpAndSettle();
    expect(copiedIds, ['1433951']);
    expect(pressedTags, isEmpty);
    expect(haptics, ['HapticFeedbackType.lightImpact']);
    await tester.tap(find.text('Artist'));
    expect(pressedTags, ['Artist']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop ID retains its copy button', (tester) async {
    var copies = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ComicDetailIdRow(id: '123', onCopy: () => copies++),
        ),
      ),
    );
    await tester.tap(find.text('ID: 123'));
    expect(copies, 0);
    await tester.tap(find.byIcon(Icons.copy_all_outlined));
    expect(copies, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile metadata fits long tags and preserves tap and copy', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const longTag =
        'A very long comic category that should fit within a narrow phone';
    final pressed = <String>[];
    final copied = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
            child: Padding(
              padding: const EdgeInsets.all(36),
              child: ComicDetailMetaRow(
                useMobileStyle: true,
                label: 'Tags',
                values: const [longTag, 'Adventure'],
                onValuePressed: pressed.add,
                onValueLongPress: copied.add,
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    final tag = find.text(longTag);
    expect(tester.getSize(tag).width, lessThanOrEqualTo(248));
    await tester.tap(tag);
    await tester.longPress(tag);
    await tester.pumpAndSettle();
    expect(pressed, [longTag]);
    expect(copied, [longTag]);
    expect(tester.takeException(), isNull);
  });

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
