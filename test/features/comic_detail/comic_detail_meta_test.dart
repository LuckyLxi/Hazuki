import '../../support/source_presentation_fixtures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hazuki/features/comic_detail/view/comic_detail_meta.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/models/hazuki_models.dart';

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
      infoFields: [
        ComicInfoField(
          label: 'Author',
          values: ['Artist'],
          action: ComicInfoAction.search,
        ),
        ComicInfoField(
          label: 'Tags',
          values: ['Action'],
          action: ComicInfoAction.search,
        ),
      ],
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
      infoFields: [
        ComicInfoField(
          label: 'Author',
          values: ['Artist'],
          action: ComicInfoAction.search,
        ),
        ComicInfoField(
          label: 'Tags',
          values: ['Action'],
          action: ComicInfoAction.search,
        ),
      ],
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
      infoFields: [
        ComicInfoField(
          label: 'Author',
          values: ['Artist'],
          action: ComicInfoAction.search,
        ),
        ComicInfoField(
          label: 'Categories',
          values: ['Webtoon'],
          action: ComicInfoAction.search,
        ),
        ComicInfoField(
          label: 'Tags',
          values: ['Action'],
          action: ComicInfoAction.search,
        ),
        ComicInfoField(
          label: 'Uploader',
          values: ['Uploader'],
          action: ComicInfoAction.search,
        ),
        ComicInfoField(
          label: 'Chinese team',
          values: ['Team A'],
          action: ComicInfoAction.search,
        ),
      ],
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
      infoFields: [
        ComicInfoField(
          label: 'Author',
          values: ['Artist'],
          action: ComicInfoAction.search,
        ),
        ComicInfoField(
          label: 'Tags',
          values: ['Action'],
          action: ComicInfoAction.search,
        ),
        ComicInfoField(
          label: '作品',
          values: ['Original'],
          action: ComicInfoAction.search,
        ),
        ComicInfoField(
          label: '角色',
          values: ['Heroine'],
          action: ComicInfoAction.search,
        ),
      ],
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

  for (final mobile in [true, false]) {
    testWidgets(
      'plugin rows preserve labels, order and actions (mobile=$mobile)',
      (tester) async {
        final searched = <String>[];
        final copied = <String>[];
        final details = _customDetails();
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ComicDetailMetaSection(
                details: details,
                showComicId: false,
                useMobileStyle: mobile,
                onCopyId: (_) {},
                onTagValuePressed: searched.add,
                onMetaValueLongPress: copied.add,
              ),
            ),
          ),
        );
        final rows = tester
            .widgetList<ComicDetailMetaRow>(find.byType(ComicDetailMetaRow))
            .toList();
        expect(rows.map((r) => r.label), [
          'Status',
          'Original story',
          'Publisher',
        ]);
        expect(find.text('Should not leak'), findsNothing);
        expect(find.text('Legacy uploader'), findsNothing);
        expect(find.text('Hidden'), findsNothing);
        expect(rows.first.onValuePressed, isNull);
        await tester.tap(find.text('Ongoing'));
        expect(searched, isEmpty);
        expect(copied, isEmpty);
        await tester.tap(find.text('Name, with/slashes'));
        expect(searched, ['Name, with/slashes']);
        await tester.tap(find.text('Publisher A'));
        expect(copied, ['Publisher A']);
        await tester.longPress(find.text('Ongoing'));
        expect(copied, ['Publisher A', 'Ongoing']);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('language maps follow the page locale without changing data', (
    tester,
  ) async {
    Future<void> render(Locale locale) => tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ComicDetailMetaSection(
            details: _customDetails(),
            showComicId: false,
            onCopyId: (_) {},
            onTagValuePressed: (_) {},
            onMetaValueLongPress: (_) {},
          ),
        ),
      ),
    );
    await render(const Locale('en'));
    expect(find.text('Status: '), findsOneWidget);
    await render(const Locale('zh', 'CN'));
    await tester.pumpAndSettle();
    expect(find.text('状态: '), findsOneWidget);
    expect(find.text('Ongoing'), findsOneWidget);
  });
}

ComicDetailsData _customDetails() => const ComicDetailsData(
  id: 'custom',
  title: 'Comic',
  subTitle: '',
  cover: '',
  description: '',
  updateTime: '',
  likesCount: '',
  chapters: {},
  tags: {
    'Author': ['Should not leak'],
    'Status': ['Should not leak'],
  },
  uploader: 'Legacy uploader',
  recommend: [],
  isFavorite: false,
  subId: '',
  infoFields: [
    ComicInfoField(label: {'zh': '状态', 'en': 'Status'}, values: ['Ongoing']),
    ComicInfoField(
      label: 'Original story',
      values: ['Name, with/slashes'],
      action: ComicInfoAction.search,
    ),
    ComicInfoField(label: 'Hidden', values: []),
    ComicInfoField(
      label: 'Publisher',
      values: ['Publisher A'],
      action: ComicInfoAction.copy,
    ),
  ],
);
