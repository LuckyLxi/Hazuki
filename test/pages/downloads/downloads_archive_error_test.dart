import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/downloads/view/downloads_task_card.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/services/manga_download/manga_download_models.dart';

void main() {
  for (final locale in ['zh', 'en']) {
    for (final extraction in [true, false]) {
      testWidgets(
        'archive failure shows details without overflowing ($locale, extraction=$extraction)',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(390, 844));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          const path = '/downloads/comic/MangaChapter001/archives/chapter.zip';
          const task = MangaDownloadTask(
            comicId: 'comic',
            sourceKey: 'sample',
            title: 'Comic',
            subTitle: '',
            description: '',
            coverUrl: '',
            targets: [
              MangaChapterDownloadTarget(
                epId: 'chapter',
                title: 'Chapter',
                index: 0,
              ),
            ],
            completedEpIds: {},
            status: MangaDownloadTaskStatus.failed,
            createdAtMillis: 1,
            updatedAtMillis: 1,
            errorMessage: '$mangaArchiveExtractionErrorPrefix$path',
          );
          final networkError = 'HTTP 503: ${'server unavailable ' * 40}';
          final shownTask = extraction
              ? task
              : task.copyWith(
                  errorMessage: '$mangaArchiveDownloadErrorPrefix$networkError',
                );
          await tester.pumpWidget(
            MaterialApp(
              locale: Locale(locale),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: DownloadsOngoingTaskCard(
                  task: shownTask,
                  onPauseTask: (_) {},
                  onResumeTask: (_) {},
                  onDeleteTask: (_) {},
                ),
              ),
            ),
          );
          final strings = await AppLocalizations.delegate.load(Locale(locale));
          expect(
            find.text(
              extraction
                  ? strings.downloadsArchiveExtractionFailed(path)
                  : networkError,
            ),
            findsOneWidget,
          );
          expect(
            find.text(
              extraction
                  ? strings.downloadsArchiveExtractionStatus
                  : strings.downloadsArchiveDownloadStatus,
            ),
            findsOneWidget,
          );
          expect(
            find.textContaining(mangaArchiveExtractionErrorPrefix),
            findsNothing,
          );
        },
      );
    }
  }
}
