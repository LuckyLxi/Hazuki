import 'package:hazuki/widgets/hazuki_frosted_menu_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/models/comic_detail_models.dart';
import 'package:hazuki/shared/chapter_title_resolver.dart';
import 'package:hazuki/features/comic_detail/view/comic_detail_chapters_panel.dart';

void main() {
  testWidgets(
    'group switching preserves download selections and global chapter indices',
    (tester) async {
      const groups = [
        ComicChapterGroup(
          id: 'a',
          title: 'Serial',
          chapters: {'10': 'Chapter A', '2': 'Chapter B'},
        ),
        ComicChapterGroup(
          id: 'b',
          title: 'Other',
          chapters: {'1': 'Chapter C'},
        ),
      ];
      final taps = <int>[];
      Set<String>? selected;
      await _openPanel(
        tester,
        chapters: const {'10': 'Chapter A', '2': 'Chapter B', '1': 'Chapter C'},
        chapterGroups: groups,
        onChapterTap: (_, _, index) => taps.add(index),
        onDownloadConfirm: (value) => selected = value,
      );
      await tester.tap(find.byType(HazukiFrostedDropdown<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Other').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chapter C'));
      expect(taps, [2]);
      await tester.tap(find.byIcon(Icons.download_outlined).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chapter C'));
      await tester.tap(find.byType(HazukiFrostedDropdown<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Serial').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chapter A'));
      await tester.tap(find.byType(FilledButton));
      expect(selected, {'1', '10'});
    },
  );
  testWidgets('chapter taps preserve the source id, resolved title and index', (
    tester,
  ) async {
    (String, String, int)? opened;
    await _openPanel(
      tester,
      chapters: const {
        'special': hazukiDefaultChapterTitleToken,
        'next': 'Next',
      },
      onChapterTap: (id, title, index) => opened = (id, title, index),
    );

    expect(find.text('A comic title'), findsOneWidget);
    await tester.tap(find.text('Chapter 1'));
    expect(opened, ('special', 'Chapter 1', 0));
    await tester.tap(find.text('Next'));
    expect(opened, ('next', 'Next', 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('download mode selects individual chapters and toggles all', (
    tester,
  ) async {
    final downloads = <Set<String>>[];
    await _openPanel(tester, onDownloadConfirm: downloads.add);
    await tester.tap(find.text('Download'));
    await tester.pumpAndSettle();

    FilledButton confirmButton() => tester.widget<FilledButton>(
      find.widgetWithIcon(FilledButton, Icons.download_rounded),
    );

    expect(confirmButton().onPressed, isNull);
    expect(find.text('0 / 3'), findsOneWidget);
    await tester.tap(find.text('Chapter 2'));
    await tester.pumpAndSettle();
    expect(find.text('1 / 3'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    await tester.tap(find.widgetWithIcon(FilledButton, Icons.download_rounded));
    expect(downloads, [
      <String>{'ep-2'},
    ]);

    await tester.tap(find.text('Select all'));
    await tester.pumpAndSettle();
    expect(find.text('3 / 3'), findsOneWidget);
    await tester.tap(find.text('Clear all'));
    await tester.pumpAndSettle();
    expect(confirmButton().onPressed, isNull);
    // The callback receives a snapshot, unaffected by subsequent selection.
    expect(downloads.single, <String>{'ep-2'});
    expect(tester.takeException(), isNull);
  });

  testWidgets('mode switches retain the grid and its scroll position', (
    tester,
  ) async {
    await _openPanel(
      tester,
      chapters: {for (var i = 1; i <= 120; i++) 'ep-$i': 'Chapter $i'},
    );
    final gridFinder = find.byKey(const ValueKey('chapter-grid'));
    final controller = tester.widget<GridView>(gridFinder).controller!;
    await tester.drag(gridFinder, const Offset(0, -300));
    await tester.pumpAndSettle();
    final offset = controller.offset;
    expect(offset, greaterThan(0));

    await tester.tap(find.text('Download'));
    await tester.pump(const Duration(milliseconds: 110));
    expect(find.byType(GridView), findsOneWidget);
    expect(tester.widget<GridView>(gridFinder).controller, same(controller));
    await tester.pumpAndSettle();
    expect(controller.offset, closeTo(offset, 0.1));
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(ComicDetailChaptersPanel), findsOneWidget);
    expect(find.text('Chapters'), findsOneWidget);
    expect(controller.offset, closeTo(offset, 0.1));
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(ComicDetailChaptersPanel), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'selection survives leaving download mode and close dismisses it',
    (tester) async {
      await _openPanel(tester);
      await tester.tap(find.text('Download'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chapter 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Download'));
      await tester.pumpAndSettle();
      expect(find.text('1 / 3'), findsOneWidget);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.byType(ComicDetailChaptersPanel), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final scenario in [
    (size: const Size(320, 640), scale: 1.0, dark: false),
    (size: const Size(740, 360), scale: 1.0, dark: true),
    (size: const Size(740, 360), scale: 2.0, dark: true),
    (size: const Size(320, 640), scale: 2.0, dark: true),
  ]) {
    testWidgets('panel fits $scenario with long titles and safe insets', (
      tester,
    ) async {
      tester.view.physicalSize = scenario.size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _openPanel(
        tester,
        textScale: scenario.scale,
        dark: scenario.dark,
        chapters: {
          for (var i = 1; i <= 12; i++)
            'ep-$i':
                'Chapter $i: A very long chapter title to display on two lines',
        },
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Download'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Select all'));
      await tester.pumpAndSettle();
      expect(find.text('12 / 12'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(
        tester
            .getBottomRight(
              find.widgetWithIcon(FilledButton, Icons.download_rounded),
            )
            .dy,
        lessThanOrEqualTo(scenario.size.height - 24),
      );
    });
  }

  testWidgets('reduced motion still updates selection immediately', (
    tester,
  ) async {
    await _openPanel(tester, disableAnimations: true);
    await tester.tap(find.text('Download'));
    await tester.pump();
    await tester.tap(find.text('Chapter 1'));
    await tester.pump();
    expect(find.text('1 / 3'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _openPanel(
  WidgetTester tester, {
  List<ComicChapterGroup> chapterGroups = const [],
  Map<String, String> chapters = const {
    'ep-1': 'Chapter 1',
    'ep-2': 'Chapter 2',
    'ep-3': 'Chapter 3',
  },
  void Function(String, String, int)? onChapterTap,
  ValueChanged<Set<String>>? onDownloadConfirm,
  double textScale = 1,
  bool dark = false,
  bool disableAnimations = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff8d4c44),
          brightness: dark ? Brightness.dark : Brightness.light,
        ),
        platform: TargetPlatform.android,
      ),
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          padding: const EdgeInsets.only(top: 24, bottom: 24),
          disableAnimations: disableAnimations,
        ),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              backgroundColor: Colors.transparent,
              builder: (context) => ComicDetailChaptersPanel(
                details: ComicDetailsData(
                  id: 'comic',
                  title: 'A comic title',
                  subTitle: '',
                  cover: '',
                  description: '',
                  updateTime: '',
                  likesCount: '',
                  chapters: chapters,
                  chapterGroups: chapterGroups,
                  tags: const {},
                  recommend: const [],
                  isFavorite: false,
                  subId: '',
                ),
                onChapterTap: onChapterTap ?? (_, _, _) {},
                onDownloadConfirm: onDownloadConfirm ?? (_) {},
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}
