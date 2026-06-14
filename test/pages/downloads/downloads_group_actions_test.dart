import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/downloads/support/downloads_group_actions.dart';
import 'package:hazuki/features/downloads/view/downloads_cover_widgets.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/services/download_groups_service.dart';
import 'package:hazuki/services/manga_download/manga_download_service.dart';

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
    expect(find.text('Move / Add'), findsOneWidget);
    expect(find.text('Remove from this group'), findsOneWidget);
    expect(find.text('Add to group'), findsNothing);
    expect(find.text('Move to group'), findsNothing);
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
    expect(
      tester
          .widget<CheckboxListTile>(
            find.widgetWithText(CheckboxListTile, 'Default group'),
          )
          .onChanged,
      isNotNull,
    );

    await tester.tap(find.text('Default group'));
    await tester.tap(find.text('A'));
    await tester.tap(find.text('B'));
    await tester.tap(find.text('A'));
    await tester.tap(find.text('A'));
    await tester.tap(find.text('Move / Add'));
    await tester.pumpAndSettle();

    expect(result, {'a', 'b'});
  });

  testWidgets('long press menu can remove a comic from the current group', (
    tester,
  ) async {
    DownloadsComicMenuAction? result;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Builder(
              builder: (itemContext) => FilledButton(
                onPressed: () async {
                  result = await showDownloadsComicMenu(
                    context: context,
                    itemContext: itemContext,
                    globalPosition: const Offset(200, 200),
                  );
                },
                child: const Text('Open menu'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open menu'));
    await tester.pumpAndSettle();

    expect(find.text('Remove from this group'), findsOneWidget);
    await tester.tap(find.text('Remove from this group'));
    await tester.pumpAndSettle();

    expect(result, DownloadsComicMenuAction.removeFromCurrentGroup);
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
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Move / Add'))
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Move / Add'));
    await tester.pumpAndSettle();

    expect(find.text('Select at least one group'), findsOneWidget);
    final cancelCenter = tester.getCenter(
      find.widgetWithText(TextButton, 'Cancel'),
    );
    final addCenter = tester.getCenter(
      find.widgetWithText(FilledButton, 'Move / Add'),
    );
    expect(cancelCenter.dy, closeTo(addCenter.dy, 0.1));
  });

  testWidgets('bulk group dialog morphs into remove confirmation', (
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
                  selectedComics: _comics,
                  initialComicKeysByGroup: const {'a': {}},
                  currentGroupName: 'A',
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
    expect(tester.getSize(dialog), const Size(280, 250));
    expect(
      find.byKey(const ValueKey<String>('downloads_bulk_action_stage')),
      findsOneWidget,
    );

    await tester.tap(
      find.widgetWithText(FilledButton, 'Remove from this group'),
    );
    await tester.pumpAndSettle();

    expect(tester.getSize(dialog), const Size(340, 220));
    expect(
      find.byKey(
        const ValueKey<String>('downloads_bulk_remove_confirmation_stage'),
      ),
      findsOneWidget,
    );
    expect(find.text('Remove the selected comics from A?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'OK'));
    await tester.pumpAndSettle();

    expect(result?.action, DownloadsBulkGroupAction.removeFromCurrentGroup);
  });

  testWidgets('partial group can fill, restore, and edit individual comics', (
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
                  selectedComics: _comics,
                  initialComicKeysByGroup: const {
                    'a': {'comic-a'},
                    'b': {},
                  },
                  currentGroupName: 'A',
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
    await tester.tap(find.widgetWithText(FilledButton, 'Move / Add'));
    await tester.pumpAndSettle();

    final partialTile = find.widgetWithText(CheckboxListTile, 'A');
    expect(tester.widget<CheckboxListTile>(partialTile).value, isNull);
    expect(find.widgetWithText(TextButton, 'View'), findsOneWidget);

    await tester.tap(partialTile);
    await tester.pump();
    expect(tester.widget<CheckboxListTile>(partialTile).value, isTrue);
    expect(find.widgetWithText(TextButton, 'View'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextButton, 'View'), findsNothing);
    await tester.tap(partialTile);
    await tester.pump();
    expect(tester.widget<CheckboxListTile>(partialTile).value, isNull);
    expect(find.widgetWithText(TextButton, 'View'), findsOneWidget);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'View'));
    await tester.pump(const Duration(milliseconds: 120));
    expect(
      find.byKey(
        const ValueKey<String>('downloads_group_membership_details_transition'),
      ),
      findsOneWidget,
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(
        const ValueKey<String>('downloads_group_membership_details_dialog'),
      ),
      findsOneWidget,
    );
    expect(find.byType(SegmentedButton<bool>), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('downloads_membership_slider')),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<String>('downloads_membership_content_switcher'),
      ),
      findsOneWidget,
    );
    expect(find.byType(DownloadedComicCover), findsOneWidget);

    await tester.tap(find.byType(DownloadedComicCover));
    await tester.pump();
    final dismissingCover = tester.widget<AnimatedOpacity>(
      find.byKey(const ValueKey<String>('downloads_membership_cover_comic-b')),
    );
    expect(dismissingCover.opacity, 0);
    expect(find.byType(DownloadedComicCover), findsOneWidget);
    await tester.tap(find.text('Joined'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      tester
          .widget<AnimatedAlign>(
            find.byKey(
              const ValueKey<String>('downloads_membership_slider_thumb'),
            ),
          )
          .alignment,
      Alignment.centerRight,
    );
    expect(find.byType(DownloadedComicCover), findsNWidgets(3));
    await tester.pumpAndSettle();
    expect(find.byType(DownloadedComicCover), findsNWidgets(2));
    await tester.tap(find.byType(DownloadedComicCover).first);
    await tester.pump();
    final detailsDialog = find.byKey(
      const ValueKey<String>('downloads_group_membership_details_dialog'),
    );
    await tester.tap(
      find.descendant(
        of: detailsDialog,
        matching: find.widgetWithText(FilledButton, 'Save'),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      find.byKey(
        const ValueKey<String>('downloads_group_membership_details_transition'),
      ),
      findsOneWidget,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(result?.action, DownloadsBulkGroupAction.updateMemberships);
    expect(result?.comicKeysByGroup['a'], {'comic-b'});
    expect(result?.comicKeysByGroup['b'], isEmpty);
  });
}

const _comics = [
  DownloadedMangaComic(
    comicId: 'comic-a',
    title: 'Comic A',
    subTitle: '',
    description: '',
    coverUrl: '',
    localCoverPath: null,
    chapters: [],
    updatedAtMillis: 0,
  ),
  DownloadedMangaComic(
    comicId: 'comic-b',
    title: 'Comic B',
    subTitle: '',
    description: '',
    coverUrl: '',
    localCoverPath: null,
    chapters: [],
    updatedAtMillis: 0,
  ),
];
