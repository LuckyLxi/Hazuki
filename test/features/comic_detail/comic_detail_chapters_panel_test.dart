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
      expect(find.byType(HazukiFrostedDropdown<String>), findsNothing);
      await tester.tap(_groupTab('Other'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chapter C'));
      expect(taps, [2]);
      await tester.tap(find.byTooltip('Download'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chapter C'));
      await tester.tap(_groupTab('Serial'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chapter A'));
      await tester.pumpAndSettle();
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

    await tester.tap(find.text('Chapter 1'));
    expect(opened, ('special', 'Chapter 1', 0));
    await tester.tap(find.text('Next'));
    expect(opened, ('next', 'Next', 1));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('download mode selects individual chapters and quick actions', (
    tester,
  ) async {
    final downloads = <Set<String>>[];
    await _openPanel(
      tester,
      readingProgress: const {'epId': 'ep-2'},
      onDownloadConfirm: downloads.add,
    );
    await tester.tap(find.byTooltip('Download'));
    await tester.pumpAndSettle();

    FilledButton confirmButton() => tester.widget<FilledButton>(
      find.widgetWithIcon(FilledButton, Icons.download_rounded),
    );

    expect(confirmButton().onPressed, isNull);
    expect(find.text('0 selected'), findsOneWidget);
    await tester.tap(find.text('Chapter 2'));
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    await tester.tap(find.widgetWithIcon(FilledButton, Icons.download_rounded));
    expect(downloads, [
      <String>{'ep-2'},
    ]);

    await tester.tap(find.text('Chapter 1'));
    await tester.pumpAndSettle();
    expect(find.text('2 selected'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(2));
    await tester.tap(find.widgetWithIcon(FilledButton, Icons.download_rounded));
    expect(downloads.last, {'ep-1', 'ep-2'});

    // 反选只作用于当前分组；“选择未读”跳过当前话之前的章节
    await tester.tap(find.text('Invert'));
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);
    // 全选与取消全选是同一个按钮，未全选时不显示取消全选
    expect(find.text('Clear all'), findsNothing);
    await tester.tap(find.text('Select all'));
    await tester.pumpAndSettle();
    expect(find.text('3 selected'), findsOneWidget);
    expect(find.text('Select all'), findsNothing);
    await tester.tap(find.text('Clear all'));
    await tester.pumpAndSettle();
    expect(find.text('0 selected'), findsOneWidget);
    await tester.tap(find.text('Unread'));
    await tester.pumpAndSettle();
    expect(find.text('2 selected'), findsOneWidget);
    await tester.tap(find.widgetWithIcon(FilledButton, Icons.download_rounded));
    expect(downloads.last, {'ep-2', 'ep-3'});

    await tester.tap(find.text('Select all'));
    await tester.pumpAndSettle();
    expect(find.text('3 selected'), findsOneWidget);
    await tester.tap(find.text('Clear all'));
    await tester.pumpAndSettle();
    expect(confirmButton().onPressed, isNull);
    // The callback receives a snapshot, unaffected by subsequent selection.
    expect(downloads.first, <String>{'ep-2'});
    expect(tester.takeException(), isNull);
  });

  testWidgets('long press enters selection with that chapter selected', (
    tester,
  ) async {
    final taps = <String>[];
    await _openPanel(tester, onChapterTap: (id, _, _) => taps.add(id));
    await tester.longPress(find.text('Chapter 3'));
    await tester.pumpAndSettle();
    expect(taps, isEmpty);
    expect(find.text('1 selected'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    await tester.tap(find.byTooltip('Exit selection'));
    await tester.pumpAndSettle();
    expect(find.text('Chapters'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reading progress marks read chapters and offers to resume', (
    tester,
  ) async {
    BuildContext? resumedFrom;
    await _openPanel(
      tester,
      readingProgress: const {'epId': 'ep-2', 'pageIndex': 11},
      onResume: (context) => resumedFrom = context,
    );
    expect(find.text('3 chapters · 1 read'), findsOneWidget);
    expect(find.text('Last read'), findsOneWidget);
    expect(find.text('Continue reading'), findsOneWidget);
    expect(find.text('Page 12'), findsOneWidget);
    await tester.tap(find.text('Continue reading'));
    expect(resumedFrom, isNotNull);

    // 多选时继续阅读卡片收起
    await tester.tap(find.byTooltip('Download'));
    await tester.pumpAndSettle();
    expect(find.text('Continue reading'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reader panel highlights the open chapter without resume card', (
    tester,
  ) async {
    await _openPanel(tester, initialChapterId: 'ep-3');
    expect(find.text('3 chapters · 2 read'), findsOneWidget);
    expect(find.text('Last read'), findsOneWidget);
    expect(find.text('Continue reading'), findsNothing);
  });

  for (final scenario in [
    (count: 6, chips: true, dropdown: false),
    (count: 10, chips: false, dropdown: true),
  ]) {
    testWidgets('group bar adapts to ${scenario.count} groups', (tester) async {
      final groups = [
        for (var i = 0; i < scenario.count; i++)
          ComicChapterGroup(
            id: 'g$i',
            title: 'Group $i',
            chapters: {'ep-$i': 'Chapter in $i'},
          ),
      ];
      await _openPanel(
        tester,
        chapters: {for (final g in groups) ...g.chapters},
        chapterGroups: groups,
      );
      expect(
        find.byType(ChoiceChip),
        scenario.chips ? findsWidgets : findsNothing,
      );
      expect(
        find.byType(HazukiFrostedDropdown<String>),
        scenario.dropdown ? findsOneWidget : findsNothing,
      );
      if (scenario.chips) {
        await tester.ensureVisible(_groupTab('Group 4'));
        await tester.pumpAndSettle();
        await tester.tap(_groupTab('Group 4'));
        await tester.pumpAndSettle();
        expect(find.text('Chapter in 4'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('layout and sort toggles keep chapters tappable', (tester) async {
    final taps = <int>[];
    await _openPanel(tester, onChapterTap: (_, _, index) => taps.add(index));
    await tester.tap(find.byTooltip('List view'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('chapter-list')), findsOneWidget);
    expect(find.byKey(const ValueKey('chapter-grid')), findsNothing);
    await tester.tap(find.byTooltip('Newest first'));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('Chapter 3')).dy,
      lessThan(tester.getTopLeft(find.text('Chapter 1')).dy),
    );
    await tester.tap(find.text('Chapter 1'));
    expect(taps, [0]);
    await tester.tap(find.byTooltip('Grid view'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('chapter-grid')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dragging the header expands and dismisses the panel', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _openPanel(tester);
    final panel = find.byType(ComicDetailChaptersPanel);
    final halfHeight = tester.getSize(panel).height;
    await tester.drag(find.text('Chapters'), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(tester.getSize(panel).height, greaterThan(halfHeight));
    await tester.drag(find.text('Chapters'), const Offset(0, 300));
    await tester.pumpAndSettle();
    expect(tester.getSize(panel).height, closeTo(halfHeight, 0.5));
    await tester.drag(find.text('Chapters'), const Offset(0, 300));
    await tester.pumpAndSettle();
    expect(panel, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exit button appears at its final position while switching', (
    tester,
  ) async {
    await _openPanel(tester);
    await tester.tap(find.byTooltip('Download'));
    await tester.pump(const Duration(milliseconds: 60));
    final during = tester.getCenter(find.byTooltip('Exit selection')).dx;
    await tester.pumpAndSettle();
    final settled = tester.getCenter(find.byTooltip('Exit selection')).dx;
    expect(during, closeTo(settled, 0.5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('pulling the list down at its top drags the panel closed', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _openPanel(
      tester,
      chapters: {for (var i = 1; i <= 120; i++) 'ep-$i': 'Chapter $i'},
      readingProgress: const {'epId': 'ep-60'},
    );
    final gridFinder = find.byKey(const ValueKey('chapter-grid'));
    final controller = tester.widget<GridView>(gridFinder).controller!;
    // 打开时定位到当前章节，下拉先滚动列表
    expect(controller.offset, greaterThan(0));
    await tester.drag(gridFinder, const Offset(0, 120));
    await tester.pumpAndSettle();
    expect(find.byType(ComicDetailChaptersPanel), findsOneWidget);
    controller.jumpTo(0);
    await tester.pump();
    // 已在顶部：短距离下拉回弹，长距离下拉关闭
    await tester.drag(gridFinder, const Offset(0, 80));
    await tester.pumpAndSettle();
    expect(find.byType(ComicDetailChaptersPanel), findsOneWidget);
    await tester.drag(gridFinder, const Offset(0, 400));
    await tester.pumpAndSettle();
    expect(find.byType(ComicDetailChaptersPanel), findsNothing);
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

    await tester.tap(find.byTooltip('Download'));
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

  testWidgets('selection survives leaving download mode and back dismisses', (
    tester,
  ) async {
    await _openPanel(tester);
    await tester.tap(find.byTooltip('Download'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chapter 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Exit selection'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Download'));
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(ComicDetailChaptersPanel), findsNothing);
    expect(tester.takeException(), isNull);
  });

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
        readingProgress: const {'epId': 'ep-4', 'pageIndex': 3},
        onResume: (_) {},
        chapters: {
          for (var i = 1; i <= 12; i++)
            'ep-$i':
                'Chapter $i: A very long chapter title to display on two lines',
        },
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Download'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Select all'));
      await tester.pumpAndSettle();
      expect(find.text('12 selected'), findsOneWidget);
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
    await tester.tap(find.byTooltip('Download'));
    await tester.pump();
    await tester.tap(find.text('Chapter 1'));
    await tester.pump();
    expect(find.text('1 selected'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('chapter tiles stay visible in pure black mode', (tester) async {
    await _openPanel(
      tester,
      dark: true,
      pureBlack: true,
      readingProgress: const {'epId': 'ep-2'},
    );
    Color tileColor(String title) => tester
        .widget<Material>(
          find
              .ancestor(of: find.text(title), matching: find.byType(Material))
              .first,
        )
        .color!;
    // 已读与未读格子都要和纯黑背景区分开
    expect(tileColor('Chapter 1'), isNot(Colors.black));
    expect(tileColor('Chapter 3'), isNot(Colors.black));
    expect(tileColor('Chapter 1'), isNot(tileColor('Chapter 3')));
  });
}

Finder _groupTab(String title) =>
    find.textContaining(title, findRichText: true).last;

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
  String? initialChapterId,
  Map<String, dynamic>? readingProgress,
  void Function(BuildContext)? onResume,
  double textScale = 1,
  bool dark = false,
  bool pureBlack = false,
  bool disableAnimations = false,
}) async {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xff8d4c44),
    brightness: dark ? Brightness.dark : Brightness.light,
  );
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(
        // 与应用的纯黑模式一致：所有 surface 容器都为纯黑
        colorScheme: pureBlack
            ? scheme.copyWith(
                surface: Colors.black,
                surfaceContainer: Colors.black,
                surfaceContainerLow: Colors.black,
                surfaceContainerLowest: Colors.black,
                surfaceContainerHigh: Colors.black,
                surfaceContainerHighest: Colors.black,
              )
            : scheme,
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
                initialChapterId: initialChapterId,
                readingProgress: readingProgress,
                onResume: onResume,
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
