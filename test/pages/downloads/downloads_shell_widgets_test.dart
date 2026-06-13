import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/downloads/downloads.dart';
import 'package:hazuki/l10n/app_localizations.dart';

void main() {
  testWidgets('batch group button slides in and out with selection mode', (
    tester,
  ) async {
    var visible = false;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return DownloadsBatchGroupButton(
                visible: visible,
                enabled: true,
                onPressed: () {},
              );
            },
          ),
        ),
      ),
    );

    final animation = find.byKey(
      const ValueKey<String>('downloads_batch_group_button_animation'),
    );
    expect(tester.widget<AnimatedSlide>(animation).offset.dx, 1.6);

    update(() => visible = true);
    await tester.pump();
    expect(tester.widget<AnimatedSlide>(animation).offset, Offset.zero);
    await tester.pumpAndSettle();
    expect(tester.widget<AnimatedSlide>(animation).offset, Offset.zero);

    update(() => visible = false);
    await tester.pumpAndSettle();
    expect(tester.widget<AnimatedSlide>(animation).offset.dx, 1.6);
  });

  testWidgets('multi-select action only appears on downloaded tab', (
    tester,
  ) async {
    var toggleCount = 0;

    await tester.pumpWidget(
      _wrapWithAppBar(
        initialIndex: 0,
        onToggleSelectionMode: () => toggleCount++,
      ),
    );

    expect(find.byIcon(Icons.checklist_rounded), findsNothing);

    await tester.pumpWidget(
      _wrapWithAppBar(
        initialIndex: 1,
        onToggleSelectionMode: () => toggleCount++,
      ),
    );
    await tester.tap(find.byIcon(Icons.checklist_rounded));

    expect(toggleCount, 1);
  });

  testWidgets('ongoing actions do not reserve space for select-all', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrapWithAppBar(initialIndex: 0, onToggleSelectionMode: () {}),
    );

    expect(
      find.byKey(const ValueKey<String>('downloads_select_all_button')),
      findsNothing,
    );
    final pauseButton = find.ancestor(
      of: find.byIcon(Icons.pause_rounded),
      matching: find.byType(IconButton),
    );
    expect(
      tester.getRect(pauseButton).right,
      greaterThan(tester.getSize(find.byType(Scaffold)).width - 16),
    );
  });

  testWidgets('multi-select action hides as soon as downloaded tab is left', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrapWithAppBar(initialIndex: 1, onToggleSelectionMode: () {}),
    );
    expect(find.byIcon(Icons.checklist_rounded), findsOneWidget);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(TabBarView)),
    );
    await gesture.moveBy(const Offset(80, 0));
    await tester.pump();

    expect(find.byIcon(Icons.checklist_rounded), findsNothing);

    await gesture.up();
  });

  testWidgets(
    'multi-select action appears as soon as downloaded tab is entered',
    (tester) async {
      await tester.pumpWidget(
        _wrapWithAppBar(initialIndex: 0, onToggleSelectionMode: () {}),
      );
      expect(find.byIcon(Icons.checklist_rounded), findsNothing);

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(TabBarView)),
      );
      await gesture.moveBy(const Offset(-80, 0));
      await tester.pump();

      expect(find.byIcon(Icons.checklist_rounded), findsOneWidget);

      await gesture.up();
    },
  );

  testWidgets(
    'multi-select action appears immediately when downloaded tab is tapped',
    (tester) async {
      await tester.pumpWidget(
        _wrapWithAppBar(initialIndex: 0, onToggleSelectionMode: () {}),
      );

      await tester.tap(find.byType(Tab).at(1));
      await tester.pump();

      expect(find.byIcon(Icons.checklist_rounded), findsOneWidget);
    },
  );

  testWidgets('downloaded action button switches from scan to delete', (
    tester,
  ) async {
    var scanCount = 0;
    var deleteCount = 0;

    await tester.pumpWidget(
      _wrapWithMaterial(
        DownloadsScanButton(
          selectionMode: false,
          scanning: false,
          selectedCount: 0,
          onDeleteSelected: () => deleteCount++,
          onScanDownloaded: () => scanCount++,
        ),
      ),
    );
    await tester.tap(find.byIcon(Icons.manage_search_rounded));

    expect(scanCount, 1);
    expect(deleteCount, 0);

    await tester.pumpWidget(
      _wrapWithMaterial(
        DownloadsScanButton(
          selectionMode: true,
          scanning: false,
          selectedCount: 1,
          onDeleteSelected: () => deleteCount++,
          onScanDownloaded: () => scanCount++,
        ),
      ),
    );
    await tester.tap(find.byIcon(Icons.delete_outline_rounded));

    expect(scanCount, 1);
    expect(deleteCount, 1);
  });

  testWidgets('downloaded action button animates from scan to delete', (
    tester,
  ) async {
    var selectionMode = false;
    late StateSetter updateButton;

    await tester.pumpWidget(
      _wrapWithMaterial(
        StatefulBuilder(
          builder: (context, setState) {
            updateButton = setState;
            return DownloadsScanButton(
              selectionMode: selectionMode,
              scanning: false,
              selectedCount: selectionMode ? 1 : 0,
              onDeleteSelected: () {},
              onScanDownloaded: () {},
            );
          },
        ),
      ),
    );

    final colorScheme = Theme.of(
      tester.element(find.byType(DownloadsScanButton)),
    ).colorScheme;
    expect(
      tester
          .widget<FloatingActionButton>(find.byType(FloatingActionButton))
          .backgroundColor,
      colorScheme.primaryContainer,
    );

    updateButton(() {
      selectionMode = true;
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    expect(find.byIcon(Icons.manage_search_rounded), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
    final animatedColor = tester
        .widget<FloatingActionButton>(find.byType(FloatingActionButton))
        .backgroundColor;
    expect(animatedColor, isNot(colorScheme.primaryContainer));
    expect(animatedColor, isNot(colorScheme.errorContainer));

    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.manage_search_rounded), findsNothing);
    expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
    expect(
      tester
          .widget<FloatingActionButton>(find.byType(FloatingActionButton))
          .backgroundColor,
      colorScheme.errorContainer,
    );
  });

  testWidgets('delete action is disabled without a selection', (tester) async {
    var deleteCount = 0;

    await tester.pumpWidget(
      _wrapWithMaterial(
        DownloadsScanButton(
          selectionMode: true,
          scanning: false,
          selectedCount: 0,
          onDeleteSelected: () => deleteCount++,
          onScanDownloaded: () {},
        ),
      ),
    );
    await tester.tap(find.byIcon(Icons.delete_outline_rounded));

    expect(deleteCount, 0);
  });

  testWidgets(
    'select-all button is hidden when not in selection mode on downloaded tab',
    (tester) async {
      // 非多选模式下全选按钒不可见
      await tester.pumpWidget(
        _wrapWithAppBar(
          initialIndex: 1,
          onToggleSelectionMode: () {},
          selectionMode: false,
        ),
      );
      await tester.pumpAndSettle();
      // 全选按钒应被隐藏（opacity=0 + ignorePointer）
      final button = find.byKey(
        const ValueKey<String>('downloads_select_all_button'),
      );
      expect(button, findsOneWidget);
      final opacity = tester.widget<AnimatedOpacity>(
        find.ancestor(of: button, matching: find.byType(AnimatedOpacity)),
      );
      expect(opacity.opacity, 0.0);
    },
  );

  testWidgets(
    'select-all button is visible and tappable in selection mode on downloaded tab',
    (tester) async {
      var selectAllCount = 0;
      // 多选模式下全选按钒可见且可点击
      await tester.pumpWidget(
        _wrapWithAppBar(
          initialIndex: 1,
          onToggleSelectionMode: () {},
          selectionMode: true,
          onSelectAll: () => selectAllCount++,
        ),
      );
      await tester.pumpAndSettle();
      final button = find.byKey(
        const ValueKey<String>('downloads_select_all_button'),
      );
      final opacity = tester.widget<AnimatedOpacity>(
        find.ancestor(of: button, matching: find.byType(AnimatedOpacity)),
      );
      expect(opacity.opacity, 1.0);
      await tester.tap(button);
      expect(selectAllCount, 1);
    },
  );
}

Widget _wrapWithAppBar({
  required int initialIndex,
  required VoidCallback onToggleSelectionMode,
  VoidCallback? onPauseAll,
  VoidCallback? onResumeAll,
  bool selectionMode = false,
  bool allSelected = false,
  VoidCallback? onSelectAll,
}) {
  return _wrapWithMaterial(
    DefaultTabController(
      key: ValueKey<int>(initialIndex),
      length: 2,
      initialIndex: initialIndex,
      child: Builder(
        builder: (context) => Scaffold(
          appBar: DownloadsPageAppBar(
            tabController: DefaultTabController.of(context),
            selectionMode: selectionMode,
            selectedCount: 0,
            allSelected: allSelected,
            onToggleSelectionMode: onToggleSelectionMode,
            onSelectAll: onSelectAll ?? () {},
            onPauseAll: onPauseAll ?? () {},
            onResumeAll: onResumeAll ?? () {},
          ),
          body: TabBarView(
            controller: DefaultTabController.of(context),
            children: const [SizedBox.expand(), SizedBox.expand()],
          ),
        ),
      ),
    ),
  );
}

Widget _wrapWithMaterial(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  );
}
