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
}

Widget _wrapWithAppBar({
  required int initialIndex,
  required VoidCallback onToggleSelectionMode,
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
            selectionMode: false,
            selectedCount: 0,
            onToggleSelectionMode: onToggleSelectionMode,
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
