import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/downloads/support/downloads_group_actions.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/services/download_groups_service.dart';

void main() {
  testWidgets('upward long press menu anchors to the comic top edge', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: Builder(
                builder: (itemContext) => SizedBox(
                  key: const ValueKey<String>('comic_item'),
                  height: 80,
                  width: 300,
                  child: FilledButton(
                    onPressed: () {
                      showDownloadsComicMenu(
                        context: context,
                        itemContext: itemContext,
                        globalPosition: const Offset(200, 580),
                      );
                    },
                    child: const Text('Open menu'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open menu'));
    await tester.pumpAndSettle();

    final cardRect = tester.getRect(
      find.byKey(const ValueKey<String>('comic_item')),
    );
    final menuRect = tester.getRect(
      find.byKey(const ValueKey<String>('downloads_comic_long_press_menu')),
    );
    expect(menuRect.bottom, closeTo(cardRect.top - 8, 0.1));
  });

  testWidgets('group picker saves multiple selections with one action', (
    tester,
  ) async {
    Set<String>? result;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                result = await showDownloadGroupPicker(
                  context: context,
                  groups: const [
                    DownloadGroup(
                      id: DownloadGroupsService.defaultGroupId,
                      name: DownloadGroupsService.defaultGroupName,
                      createdAtMs: 0,
                    ),
                    DownloadGroup(id: 'a', name: 'A', createdAtMs: 1),
                    DownloadGroup(id: 'b', name: 'B', createdAtMs: 2),
                  ],
                  initiallySelectedGroupIds: const {
                    DownloadGroupsService.defaultGroupId,
                  },
                  action: DownloadsComicMenuAction.move,
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final listView = tester.widget<ListView>(find.byType(ListView));
    final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
    expect(listView.padding, EdgeInsets.zero);
    expect(
      dialog.insetPadding,
      const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
    );
    expect(find.byType(CheckboxListTile), findsNWidgets(3));

    await tester.tap(find.text('A'));
    await tester.tap(find.text('B'));
    await tester.tap(find.text('Move'));
    await tester.pumpAndSettle();

    expect(result, {DownloadGroupsService.defaultGroupId, 'a', 'b'});
  });

  testWidgets('group picker only warns after saving without a group', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () {
                showDownloadGroupPicker(
                  context: context,
                  groups: const [
                    DownloadGroup(id: 'a', name: 'A', createdAtMs: 1),
                  ],
                  initiallySelectedGroupIds: const {},
                  action: DownloadsComicMenuAction.add,
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Select at least one group'), findsNothing);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Add'))
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();

    expect(find.text('Select at least one group'), findsOneWidget);
    final cancelCenter = tester.getCenter(
      find.widgetWithText(TextButton, 'Cancel'),
    );
    final addCenter = tester.getCenter(
      find.widgetWithText(FilledButton, 'Add'),
    );
    expect(cancelCenter.dy, closeTo(addCenter.dy, 0.1));
  });

  testWidgets('bulk group dialog stretches into group selection', (
    tester,
  ) async {
    DownloadsBulkGroupSelection? result;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                result = await showDownloadsBulkGroupDialog(
                  context: context,
                  groups: const [
                    DownloadGroup(id: 'a', name: 'A', createdAtMs: 1),
                  ],
                  initiallySelectedGroupIds: const {},
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final dialog = find.byKey(
      const ValueKey<String>('downloads_bulk_group_dialog'),
    );
    expect(tester.getSize(dialog), const Size(260, 250));
    expect(
      find.byKey(const ValueKey<String>('downloads_bulk_action_stage')),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Move'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 160));
    final movingSize = tester.getSize(dialog);
    expect(movingSize.width, greaterThan(260));
    expect(movingSize.width, lessThan(380));
    await tester.pumpAndSettle();

    expect(tester.getSize(dialog), const Size(380, 430));
    expect(
      find.byKey(const ValueKey<String>('downloads_bulk_group_stage')),
      findsOneWidget,
    );
    expect(find.text('Select at least one group'), findsNothing);

    await tester.tap(find.widgetWithText(FilledButton, 'Move'));
    await tester.pumpAndSettle();
    expect(find.text('Select at least one group'), findsOneWidget);
    final backCenter = tester.getCenter(
      find.widgetWithText(TextButton, 'Back'),
    );
    final moveCenter = tester.getCenter(
      find.widgetWithText(FilledButton, 'Move'),
    );
    expect(backCenter.dy, closeTo(moveCenter.dy, 0.1));

    await tester.tap(find.text('A'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Move'));
    await tester.pumpAndSettle();

    expect(result?.action, DownloadsComicMenuAction.move);
    expect(result?.groupIds, {'a'});
  });

  testWidgets('bulk group dialog starts with common groups selected', (
    tester,
  ) async {
    DownloadsBulkGroupSelection? result;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                result = await showDownloadsBulkGroupDialog(
                  context: context,
                  groups: const [
                    DownloadGroup(id: 'a', name: 'A', createdAtMs: 1),
                    DownloadGroup(id: 'b', name: 'B', createdAtMs: 2),
                  ],
                  initiallySelectedGroupIds: const {'a'},
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'Remove'), findsNothing);
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<CheckboxListTile>(find.widgetWithText(CheckboxListTile, 'A'))
          .value,
      isTrue,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();

    expect(result?.action, DownloadsComicMenuAction.add);
    expect(result?.groupIds, {'a'});
  });
}
