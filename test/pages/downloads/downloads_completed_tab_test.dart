import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/downloads/view/downloads_completed_tab.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/services/manga_download/manga_download_service.dart';

void main() {
  testWidgets('swiping a downloaded comic left reveals its delete action', (
    tester,
  ) async {
    DownloadedMangaComic? deletedComic;

    await tester.pumpWidget(
      _wrapTab(onDeleteComic: (comic) => deletedComic = comic),
    );

    final title = find.text('Test Comic');
    final originalLeft = tester.getTopLeft(title).dx;

    await tester.drag(title, const Offset(-120, 0));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(title).dx, closeTo(originalLeft - 58, 0.1));

    final deleteButton = find.byKey(
      const ValueKey<String>('downloaded_edge_delete_comic-1'),
    );
    expect(
      tester.getTopRight(deleteButton).dx,
      tester.view.physicalSize.width / tester.view.devicePixelRatio,
    );

    await tester.tap(find.byIcon(Icons.delete_outline_rounded));

    expect(deletedComic, _comic);
  });

  testWidgets('incremental left swipe reveals a downloaded comic', (
    tester,
  ) async {
    await tester.pumpWidget(_wrapTabInTabBarView());

    final title = find.text('Test Comic');
    final originalLeft = tester.getTopLeft(title).dx;
    final gesture = await tester.startGesture(tester.getCenter(title));

    for (int i = 0; i < 12; i++) {
      await gesture.moveBy(const Offset(-10, 0));
      await tester.pump();
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(title).dx, closeTo(originalLeft - 58, 0.1));
    expect(
      find.byKey(const ValueKey<String>('downloaded_edge_delete_comic-1')),
      findsOneWidget,
    );
  });

  testWidgets('left swipe has resisted overshoot before settling open', (
    tester,
  ) async {
    await tester.pumpWidget(_wrapTab());

    final title = find.text('Test Comic');
    final originalLeft = tester.getTopLeft(title).dx;
    final gesture = await tester.startGesture(tester.getCenter(title));

    await gesture.moveBy(const Offset(-140, 0));
    await tester.pump();

    final draggedDistance = originalLeft - tester.getTopLeft(title).dx;
    expect(draggedDistance, greaterThan(58));
    expect(draggedDistance, lessThan(100));

    await gesture.up();
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(title).dx, closeTo(originalLeft - 58, 0.1));
  });

  testWidgets(
    'downloaded comic animation clip allows horizontal swipe overflow',
    (tester) async {
      await tester.pumpWidget(_wrapTab());

      final clipFinder = find.descendant(
        of: find.byKey(const ValueKey<String>('downloaded_comic-1')),
        matching: find.byType(ClipRect),
      );
      final clipRect = tester.widget<ClipRect>(clipFinder);
      final clip = clipRect.clipper!.getClip(tester.getSize(clipFinder));

      expect(clip.left, lessThanOrEqualTo(-76));
      expect(
        clip.right,
        greaterThanOrEqualTo(tester.getSize(clipFinder).width + 76),
      );
    },
  );

  testWidgets('downloaded comics do not swipe while selecting', (tester) async {
    await tester.pumpWidget(_wrapTab(selectionMode: true));

    final title = find.text('Test Comic');
    final originalLeft = tester.getTopLeft(title).dx;

    await tester.drag(title, const Offset(-120, 0));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(title).dx, originalLeft);
    expect(find.byIcon(Icons.circle_outlined), findsOneWidget);
  });

  testWidgets('swiping another comic closes the previously revealed comic', (
    tester,
  ) async {
    await tester.pumpWidget(_wrapTab(comics: const [_comic, _comic2]));

    final firstTitle = find.text('Test Comic');
    final secondTitle = find.text('Second Comic');
    final firstLeft = tester.getTopLeft(firstTitle).dx;
    final secondLeft = tester.getTopLeft(secondTitle).dx;

    await tester.drag(firstTitle, const Offset(-120, 0));
    await tester.pumpAndSettle();
    await tester.drag(secondTitle, const Offset(-120, 0));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(firstTitle).dx, closeTo(firstLeft, 0.1));
    expect(tester.getTopLeft(secondTitle).dx, closeTo(secondLeft - 58, 0.1));
    expect(
      find.byKey(const ValueKey<String>('downloaded_edge_delete_comic-2')),
      findsOneWidget,
    );
  });

  testWidgets('right swipe on a closed comic is passed to the tab view', (
    tester,
  ) async {
    late TabController controller;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DefaultTabController(
          length: 2,
          initialIndex: 1,
          child: Builder(
            builder: (context) {
              controller = DefaultTabController.of(context);
              return Scaffold(
                body: TabBarView(
                  controller: controller,
                  physics: const ClampingScrollPhysics(),
                  children: [const Text('Ongoing tab'), _buildTab()],
                ),
              );
            },
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Test Comic')),
    );
    await gesture.moveBy(const Offset(80, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(520, 0));
    await tester.pump();
    expect(controller.animation!.value, lessThan(1));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(controller.index, 0);
  });

  testWidgets('left swipe on a comic does not drag the tab view', (
    tester,
  ) async {
    late TabController controller;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DefaultTabController(
          length: 2,
          initialIndex: 1,
          child: Builder(
            builder: (context) {
              controller = DefaultTabController.of(context);
              return Scaffold(
                body: TabBarView(
                  controller: controller,
                  physics: const ClampingScrollPhysics(),
                  children: [const Text('Ongoing tab'), _buildTab()],
                ),
              );
            },
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Test Comic')),
    );
    await gesture.moveBy(const Offset(-80, 0));
    await tester.pump();

    expect(controller.animation!.value, 1);

    await gesture.up();
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('downloaded_edge_delete_comic-1')),
      findsOneWidget,
    );
  });

  testWidgets('reversing a held left swipe on a comic does not switch tabs', (
    tester,
  ) async {
    late TabController controller;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DefaultTabController(
          length: 2,
          initialIndex: 1,
          child: Builder(
            builder: (context) {
              controller = DefaultTabController.of(context);
              return Scaffold(
                body: TabBarView(
                  controller: controller,
                  physics: const ClampingScrollPhysics(),
                  children: [const Text('Ongoing tab'), _buildTab()],
                ),
              );
            },
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Test Comic')),
    );
    await gesture.moveBy(const Offset(-80, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(520, 0));
    await tester.pump();

    expect(controller.animation!.value, 1);

    await gesture.up();
    await tester.pumpAndSettle();

    expect(controller.index, 1);
  });

  testWidgets('right swipe closes a revealed comic completely', (tester) async {
    await tester.pumpWidget(_wrapTab());

    final title = find.text('Test Comic');
    final originalLeft = tester.getTopLeft(title).dx;

    await tester.drag(title, const Offset(-120, 0));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey<String>('downloaded_comic-1')),
      const Offset(32, 0),
    );
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(title).dx, closeTo(originalLeft, 0.1));
    expect(
      find.byKey(const ValueKey<String>('downloaded_edge_delete_comic-1')),
      findsNothing,
    );
  });

  testWidgets('leaving the downloaded tab closes a revealed comic', (
    tester,
  ) async {
    await tester.pumpWidget(_wrapTab());

    final title = find.text('Test Comic');
    final originalLeft = tester.getTopLeft(title).dx;

    await tester.drag(title, const Offset(-120, 0));
    await tester.pumpAndSettle();
    await tester.pumpWidget(_wrapTab(active: false));
    await tester.pumpAndSettle();
    await tester.pumpWidget(_wrapTab());
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(title).dx, closeTo(originalLeft, 0.1));
    expect(
      find.byKey(const ValueKey<String>('downloaded_edge_delete_comic-1')),
      findsNothing,
    );
  });
}

Widget _wrapTab({
  bool active = true,
  bool selectionMode = false,
  List<DownloadedMangaComic> comics = const [_comic],
  ValueChanged<DownloadedMangaComic>? onDeleteComic,
}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: _buildTab(
        active: active,
        selectionMode: selectionMode,
        comics: comics,
        onDeleteComic: onDeleteComic,
      ),
    ),
  );
}

Widget _wrapTabInTabBarView() {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: DefaultTabController(
      length: 2,
      initialIndex: 1,
      child: Scaffold(
        body: TabBarView(
          physics: const ClampingScrollPhysics(),
          children: [const Text('Ongoing tab'), _buildTab()],
        ),
      ),
    ),
  );
}

Widget _buildTab({
  bool active = true,
  bool selectionMode = false,
  List<DownloadedMangaComic> comics = const [_comic],
  ValueChanged<DownloadedMangaComic>? onDeleteComic,
}) {
  return DownloadsCompletedTab(
    comics: comics,
    active: active,
    selectionMode: selectionMode,
    scanning: false,
    selectedCount: 0,
    selectedComicIds: const {},
    comicsWithIntegrityIssues: const {},
    onToggleSelection: (_) {},
    onDeleteSelected: () {},
    onScanDownloaded: () {},
    onOpenComic: (_) {},
    onDeleteComic: onDeleteComic ?? (_) {},
  );
}

const _comic = DownloadedMangaComic(
  comicId: 'comic-1',
  title: 'Test Comic',
  subTitle: 'Subtitle',
  description: 'Description',
  coverUrl: '',
  localCoverPath: null,
  chapters: [],
  updatedAtMillis: 0,
);

const _comic2 = DownloadedMangaComic(
  comicId: 'comic-2',
  title: 'Second Comic',
  subTitle: 'Subtitle',
  description: 'Description',
  coverUrl: '',
  localCoverPath: null,
  chapters: [],
  updatedAtMillis: 0,
);
