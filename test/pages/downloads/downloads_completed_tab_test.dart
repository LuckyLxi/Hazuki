import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/downloads/view/downloads_completed_tab.dart';
import 'package:hazuki/features/downloads/view/downloads_shell_widgets.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/services/manga_download/manga_download_service.dart';
import 'package:hazuki/services/download_groups_service.dart';

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

  testWidgets('returning from another comic leaves the revealed comic closed', (
    tester,
  ) async {
    DownloadedMangaComic? openedComic;
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      _wrapTab(
        navigatorKey: navigatorKey,
        comics: const [_comic, _comic2],
        onOpenComic: (comic) async {
          openedComic = comic;
          await navigatorKey.currentState!.push<void>(
            MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('Comic details')),
            ),
          );
        },
      ),
    );

    final firstTitle = find.text('Test Comic');
    final firstLeft = tester.getTopLeft(firstTitle).dx;

    await tester.drag(firstTitle, const Offset(-120, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Second Comic'));
    await tester.pumpAndSettle();
    expect(find.text('Comic details'), findsOneWidget);

    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();

    expect(openedComic, _comic2);
    expect(tester.getTopLeft(firstTitle).dx, closeTo(firstLeft, 0.1));
    expect(
      find.byKey(const ValueKey<String>('downloaded_edge_delete_comic-1')),
      findsNothing,
    );
  });

  testWidgets('deleted comic flies left while following comic moves up', (
    tester,
  ) async {
    var comics = const [_comic, _comic2];
    late StateSetter updateComics;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              updateComics = setState;
              return _buildTab(
                comics: comics,
                onDeleteComic: (comic) {
                  updateComics(() {
                    comics = comics
                        .where((item) => item.storageKey != comic.storageKey)
                        .toList(growable: false);
                  });
                },
              );
            },
          ),
        ),
      ),
    );

    final firstTitle = find.text('Test Comic');
    final secondTitle = find.text('Second Comic');
    final firstLeft = tester.getTopLeft(firstTitle).dx;
    final secondTop = tester.getTopLeft(secondTitle).dy;

    await tester.drag(firstTitle, const Offset(-120, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('downloaded_edge_delete_comic-1')),
      findsNothing,
    );

    await tester.pump(DownloadsCompletedTab.dismissDuration ~/ 2);

    expect(tester.getTopLeft(firstTitle).dx, lessThan(firstLeft - 58));
    expect(tester.getTopLeft(secondTitle).dy, lessThan(secondTop));

    await tester.pumpAndSettle();

    expect(firstTitle, findsNothing);
    expect(secondTitle, findsOneWidget);
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

  testWidgets('category launcher morphs into a category shell dialog', (
    tester,
  ) async {
    await tester.pumpWidget(_wrapTab());

    final launcher = find.byKey(
      const ValueKey<String>('downloads_category_launcher'),
    );
    expect(tester.getSize(launcher).height, 36);
    final launcherDecoration =
        tester.widget<DecoratedBox>(launcher).decoration as BoxDecoration;
    expect(launcherDecoration.gradient, isNull);
    expect(launcherDecoration.color, isNotNull);
    expect(launcherDecoration.borderRadius, BorderRadius.circular(12));
    expect(launcherDecoration.boxShadow, isNotEmpty);

    await tester.tap(launcher);
    await tester.pump();

    final dialog = find.byKey(
      const ValueKey<String>('downloads_category_dialog'),
    );
    expect(dialog, findsOneWidget);
    final initialDialogRect = tester.getRect(dialog);
    expect(initialDialogRect.height, closeTo(36, 0.1));
    expect(
      tester
          .widget<Opacity>(
            find.byKey(
              const ValueKey<String>('downloads_category_launcher_opacity'),
            ),
          )
          .opacity,
      0,
    );
    final initialDialogMaterial = tester.widget<Material>(dialog);
    expect(initialDialogMaterial.color, launcherDecoration.color);

    await tester.pump(const Duration(milliseconds: 100));

    final movingDialogRect = tester.getRect(dialog);
    expect(movingDialogRect.height, greaterThan(initialDialogRect.height));
    expect(movingDialogRect.height, lessThan(420));
    expect(movingDialogRect.top, greaterThan(initialDialogRect.top));
    expect(movingDialogRect.width, closeTo(initialDialogRect.width, 0.1));

    await tester.pumpAndSettle();

    expect(tester.getSize(dialog).height, closeTo(420, 0.1));
    expect(find.text('Switch group'), findsOneWidget);
    expect(find.text('Default group (1)'), findsWidgets);
    expect(find.byIcon(Icons.create_new_folder_outlined), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsNothing);
    expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsNothing);

    await tester.tapAt(const Offset(4, 4));
    await tester.pump();
    expect(
      tester
          .widget<Opacity>(
            find.byKey(
              const ValueKey<String>('downloads_category_launcher_opacity'),
            ),
          )
          .opacity,
      0,
    );

    await tester.pump(const Duration(milliseconds: 420));

    expect(
      tester
          .widget<Opacity>(
            find.byKey(
              const ValueKey<String>('downloads_category_launcher_opacity'),
            ),
          )
          .opacity,
      0,
    );

    await tester.pump();

    expect(dialog, findsOneWidget);
    expect(
      tester
          .widget<Opacity>(
            find.byKey(
              const ValueKey<String>('downloads_category_launcher_opacity'),
            ),
          )
          .opacity,
      0,
    );

    await tester.pumpAndSettle();

    expect(dialog, findsNothing);
    expect(
      tester
          .widget<Opacity>(
            find.byKey(
              const ValueKey<String>('downloads_category_launcher_opacity'),
            ),
          )
          .opacity,
      1,
    );
  });

  testWidgets('category launcher visibly bounces after returning', (
    tester,
  ) async {
    var visible = true;
    var landingVersion = 0;
    late StateSetter updateLauncher;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              updateLauncher = setState;
              return DownloadsCategoryMorphLauncher(
                visible: visible,
                landingVersion: landingVersion,
                label: 'Default group',
                comicCount: 1,
                onPressed: () {},
              );
            },
          ),
        ),
      ),
    );

    updateLauncher(() {
      visible = false;
    });
    await tester.pump();
    updateLauncher(() {
      visible = true;
      landingVersion++;
    });
    await tester.pump();

    final landing = find.byKey(
      const ValueKey<String>('downloads_category_launcher_landing'),
    );
    expect(
      tester.widget<Transform>(landing).transform.getTranslation().y,
      closeTo(-3, 0.1),
    );

    await tester.pump(const Duration(milliseconds: 150));

    expect(
      tester.widget<Transform>(landing).transform.getTranslation().y,
      isNot(closeTo(0, 0.1)),
    );

    await tester.pumpAndSettle();

    expect(
      tester.widget<Transform>(landing).transform.getTranslation().y,
      closeTo(0, 0.1),
    );
  });

  testWidgets('category dialog creates and deletes non-default groups', (
    tester,
  ) async {
    final deleted = <String>[];
    await tester.pumpWidget(
      _wrapTab(onDeleteGroup: (groupId) async => deleted.add(groupId)),
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('downloads_category_launcher')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.create_new_folder_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Enter a group name'), findsOneWidget);
    final createButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Create'),
    );
    expect(createButton.onPressed, isNull);
    await tester.enterText(find.byType(TextField), 'Favorites');
    await tester.pump();
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(find.text('Favorites (0)'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(deleted, ['new-group']);
    expect(find.text('Favorites (0)'), findsNothing);
  });

  testWidgets('category dialog renames custom groups with validation', (
    tester,
  ) async {
    final renamed = <String>[];
    await tester.pumpWidget(
      _wrapTab(
        groups: const [_defaultGroup, _firstGroup],
        onRenameGroup: (groupId, name) async {
          renamed.add('$groupId:$name');
          return DownloadGroup(id: groupId, name: name, createdAtMs: 1);
        },
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('downloads_category_launcher')),
    );
    await tester.pumpAndSettle();
    final defaultGroupBackground = find.byKey(
      const ValueKey<String>(
        'download_group_background_${DownloadGroupsService.defaultGroupId}',
      ),
    );
    expect(
      tester
          .widget<InkWell>(
            find.descendant(
              of: defaultGroupBackground,
              matching: find.byType(InkWell),
            ),
          )
          .onLongPress,
      isNull,
    );

    await tester.longPress(
      find.byKey(const ValueKey<String>('download_group_background_first')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('downloads_rename_group_transition')),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextField), '');
    await tester.pump();
    expect(find.text('Enter a group name'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'))
          .onPressed,
      isNull,
    );
    await tester.enterText(find.byType(TextField), 'Renamed');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(renamed, ['first:Renamed']);
    expect(find.text('Renamed (0)'), findsOneWidget);
  });

  testWidgets('category dialog reorders custom groups and saves', (
    tester,
  ) async {
    final savedOrders = <List<String>>[];
    await tester.pumpWidget(
      _wrapTab(
        groups: const [_defaultGroup, _firstGroup, _secondGroup],
        onReorderGroups: (groupIds) async => savedOrders.add(groupIds),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('downloads_category_launcher')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('downloads_group_sort_start')),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.delete_outline), findsNothing);
    expect(find.byIcon(Icons.drag_handle_rounded), findsNWidgets(2));
    expect(
      tester
          .widget<IconButton>(
            find
                .ancestor(
                  of: find.byIcon(Icons.create_new_folder_outlined),
                  matching: find.byType(IconButton),
                )
                .first,
          )
          .onPressed,
      isNull,
    );

    await tester.drag(
      find.byType(ReorderableDragStartListener).last,
      const Offset(0, -120),
    );
    await tester.pumpAndSettle();
    final saveButton = find.byKey(
      const ValueKey<String>('downloads_group_sort_save'),
    );
    final saveButtonRight = tester.getRect(saveButton).right;
    await tester.tap(saveButton);
    await tester.pump();
    expect(
      tester
          .getRect(
            find.byKey(const ValueKey<String>('downloads_group_sort_start')),
          )
          .right,
      closeTo(saveButtonRight, 0.1),
    );
    await tester.pumpAndSettle();

    expect(savedOrders, [
      ['second', 'first'],
    ]);
    expect(
      find.byKey(const ValueKey<String>('downloads_group_sort_start')),
      findsOneWidget,
    );
  });

  testWidgets(
    'category launcher stays above comics while they scroll underneath',
    (tester) async {
      final comics = List<DownloadedMangaComic>.generate(
        8,
        (index) => _comicAt(index),
      );
      await tester.pumpWidget(_wrapTab(comics: comics));

      final launcher = find.byKey(
        const ValueKey<String>('downloads_category_launcher'),
      );
      final firstComic = find.text('Comic 0');
      final launcherRect = tester.getRect(launcher);

      await tester.drag(firstComic, const Offset(0, -100));
      await tester.pumpAndSettle();

      final comicRect = tester.getRect(firstComic);
      expect(comicRect.top, lessThan(launcherRect.bottom));
      expect(comicRect.bottom, greaterThan(launcherRect.top));

      await tester.tap(launcher);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('downloads_category_dialog')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'back to top button slides in beside scan button after scrolling',
    (tester) async {
      final comics = List<DownloadedMangaComic>.generate(
        18,
        (index) => _comicAt(index),
      );
      await tester.pumpWidget(_wrapTab(comics: comics));

      final backAnimation = find.byKey(
        const ValueKey<String>('downloads_back_to_top_animation'),
      );
      final comicsList = tester.widget<ListView>(
        find.byKey(const ValueKey<String>('downloaded_comics_list')),
      );
      expect(comicsList.clipBehavior, Clip.hardEdge);
      expect(tester.widget<AnimatedSlide>(backAnimation).offset.dx, 1.5);

      await tester.drag(
        find.byKey(const ValueKey<String>('downloaded_comics_list')),
        const Offset(0, -700),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));

      expect(tester.widget<AnimatedSlide>(backAnimation).offset, Offset.zero);
      final scanCenter = tester.getCenter(find.byType(DownloadsScanButton));
      final backCenter = tester.getCenter(
        find.byKey(const ValueKey<String>('downloads_back_to_top_button')),
      );
      expect(backCenter.dx, greaterThan(scanCenter.dx));

      await tester.tap(
        find.byKey(const ValueKey<String>('downloads_back_to_top_button')),
      );
      await tester.pumpAndSettle();

      expect(tester.widget<AnimatedSlide>(backAnimation).offset.dx, 1.5);
      expect(find.text('Comic 0'), findsOneWidget);
    },
  );
}

Widget _wrapTab({
  GlobalKey<NavigatorState>? navigatorKey,
  bool active = true,
  bool selectionMode = false,
  List<DownloadedMangaComic> comics = const [_comic],
  ValueChanged<DownloadedMangaComic>? onOpenComic,
  ValueChanged<DownloadedMangaComic>? onDeleteComic,
  Future<void> Function(String groupId)? onDeleteGroup,
  Future<DownloadGroup> Function(String groupId, String name)? onRenameGroup,
  Future<void> Function(List<String> orderedGroupIds)? onReorderGroups,
  List<DownloadGroup> groups = const [_defaultGroup],
}) {
  return MaterialApp(
    navigatorKey: navigatorKey,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: _buildTab(
        active: active,
        selectionMode: selectionMode,
        comics: comics,
        onOpenComic: onOpenComic,
        onDeleteComic: onDeleteComic,
        onDeleteGroup: onDeleteGroup,
        onRenameGroup: onRenameGroup,
        onReorderGroups: onReorderGroups,
        groups: groups,
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
  ValueChanged<DownloadedMangaComic>? onOpenComic,
  ValueChanged<DownloadedMangaComic>? onDeleteComic,
  Future<void> Function(String groupId)? onDeleteGroup,
  Future<DownloadGroup> Function(String groupId, String name)? onRenameGroup,
  Future<void> Function(List<String> orderedGroupIds)? onReorderGroups,
  List<DownloadGroup> groups = const [_defaultGroup],
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
    onBatchGroup: () {},
    onScanDownloaded: () {},
    onOpenComic: onOpenComic ?? (_) {},
    onDeleteComic: onDeleteComic ?? (_) {},
    groups: groups,
    selectedGroupId: DownloadGroupsService.defaultGroupId,
    selectedGroupName: 'Default group',
    selectedGroupComicCount: comics.length,
    groupComicCounts: {DownloadGroupsService.defaultGroupId: comics.length},
    onSelectGroup: (_) {},
    onCreateGroup: (name) async =>
        DownloadGroup(id: 'new-group', name: name, createdAtMs: 1),
    onRenameGroup:
        onRenameGroup ??
        (groupId, name) async =>
            DownloadGroup(id: groupId, name: name, createdAtMs: 1),
    onReorderGroups: onReorderGroups ?? (_) async {},
    onDeleteGroup: onDeleteGroup ?? (_) async {},
    onShowComicMenu: (_, _, _) async {},
  );
}

const _defaultGroup = DownloadGroup(
  id: DownloadGroupsService.defaultGroupId,
  name: DownloadGroupsService.defaultGroupName,
  createdAtMs: 0,
);

const _firstGroup = DownloadGroup(
  id: 'first',
  name: 'First',
  createdAtMs: 1,
  sortOrder: 1,
);

const _secondGroup = DownloadGroup(
  id: 'second',
  name: 'Second',
  createdAtMs: 2,
  sortOrder: 2,
);

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

DownloadedMangaComic _comicAt(int index) {
  return DownloadedMangaComic(
    comicId: 'comic-$index',
    title: 'Comic $index',
    subTitle: 'Subtitle',
    description: 'Description',
    coverUrl: '',
    localCoverPath: null,
    chapters: const [],
    updatedAtMillis: index,
  );
}
