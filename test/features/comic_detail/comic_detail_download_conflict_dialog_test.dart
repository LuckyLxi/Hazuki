import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/comic_detail/support/comic_detail_download_conflict_dialog.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/services/manga_download/manga_download_models.dart';

void main() {
  testWidgets('download dialogs use the supplied comic detail theme', (
    tester,
  ) async {
    final dynamicTheme = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xffb00020)),
    );
    await tester.pumpWidget(
      _dialogTestApp(
        onPressed: (context) async {
          await showComicDetailSkipDownloadedChaptersDialog(
            context,
            conflict: _conflict,
            dialogTheme: dynamicTheme,
          );
        },
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final dialogContext = tester.element(
      find.byKey(const Key('comic-detail-skip-downloaded-dialog')),
    );
    expect(
      Theme.of(dialogContext).colorScheme.primary,
      dynamicTheme.colorScheme.primary,
    );
  });

  testWidgets('skip downloaded dialog returns skip action', (tester) async {
    ComicDetailDownloadedChapterAction? result;
    await tester.pumpWidget(
      _dialogTestApp(
        onPressed: (context) async {
          result = await showComicDetailSkipDownloadedChaptersDialog(
            context,
            conflict: _conflict,
          );
        },
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Skip downloaded chapters?'), findsOneWidget);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(result, ComicDetailDownloadedChapterAction.skip);
  });

  testWidgets('choosing no closes skip dialog before duplicate dialog opens', (
    tester,
  ) async {
    await tester.pumpWidget(
      _dialogTestApp(
        onPressed: (context) async {
          final result = await showComicDetailSkipDownloadedChaptersDialog(
            context,
            conflict: _conflict,
          );
          if (result ==
              ComicDetailDownloadedChapterAction.continueToRedownload) {
            await Future<void>.delayed(const Duration(milliseconds: 260));
            if (context.mounted) {
              await showComicDetailDownloadConflictDialog(
                context,
                conflict: _conflict,
              );
            }
          }
        },
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('No'));
    await tester.pump(const Duration(milliseconds: 259));

    expect(
      find.byKey(const Key('comic-detail-skip-downloaded-dialog')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('comic-detail-download-conflict-dialog')),
      findsNothing,
    );

    await tester.pump(const Duration(milliseconds: 1));
    expect(
      find.byKey(const Key('comic-detail-download-conflict-dialog')),
      findsOneWidget,
    );
  });

  testWidgets('duplicate download dialog animates and returns confirmation', (
    tester,
  ) async {
    bool? result;
    await tester.pumpWidget(
      _dialogTestApp(
        onPressed: (context) async {
          result = await showComicDetailDownloadConflictDialog(
            context,
            conflict: _conflict,
          );
        },
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pump();

    expect(
      find.byKey(const Key('comic-detail-download-conflict-dialog')),
      findsOneWidget,
    );
    expect(find.text('Already downloaded'), findsOneWidget);
    expect(find.textContaining('Chapter 1'), findsOneWidget);
    expect(find.byType(ScaleTransition), findsWidgets);

    await tester.pumpAndSettle();
    await tester.tap(find.text('Download again'));
    await tester.pump();

    expect(
      find.byKey(const Key('comic-detail-download-conflict-dialog')),
      findsOneWidget,
    );
    await tester.pumpAndSettle();

    expect(result, isTrue);
    expect(
      find.byKey(const Key('comic-detail-download-conflict-dialog')),
      findsNothing,
    );
  });
}

Widget _dialogTestApp({
  required Future<void> Function(BuildContext context) onPressed,
}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(
      builder: (context) {
        return TextButton(
          onPressed: () => onPressed(context),
          child: const Text('open'),
        );
      },
    ),
  );
}

const _conflict = MangaDownloadConflict(
  comicTitle: 'Hazuki',
  existingChapters: [
    MangaChapterDownloadTarget(epId: 'ep-1', title: 'Chapter 1', index: 0),
  ],
);
