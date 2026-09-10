import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/downloads/view/downloads_ongoing_tab.dart';
import 'package:hazuki/features/downloads/view/downloads_page.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/services/download_groups/download_groups_repository.dart';
import 'package:hazuki/services/manga_download/manga_download_library.dart';
import 'package:mocktail/mocktail.dart';

class _Downloads extends Mock implements MangaDownloadLibrary {}

class _Groups extends Mock implements DownloadGroupsRepository {}

void main() {
  setUpAll(() => registerFallbackValue(() {}));

  testWidgets('page observes task changes through its controller only', (
    tester,
  ) async {
    final downloads = _Downloads();
    final groups = _Groups();
    when(() => downloads.tasks).thenReturn(const []);
    when(() => downloads.downloadedComics).thenReturn(const []);
    when(() => downloads.ensureInitialized()).thenAnswer((_) async {});
    when(
      () => downloads.checkDownloadedIntegrity(),
    ).thenAnswer((_) async => {});
    when(() => groups.groups).thenReturn(const []);
    when(() => groups.comicKeysForGroup(any())).thenReturn({});
    when(
      () => groups.initialize(
        any(),
        migratedComicKeys: any(named: 'migratedComicKeys'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => groups.reconcileDownloadedComics(
        any(),
        migratedComicKeys: any(named: 'migratedComicKeys'),
      ),
    ).thenAnswer((_) async {});

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DownloadsPage(
          downloadService: downloads,
          downloadGroupsService: groups,
          readerPageBuilder: (_, _) => const SizedBox.shrink(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final subscriptions = verify(
      () => downloads.addListener(captureAny()),
    ).captured;
    expect(subscriptions, hasLength(1));
    final onDownloadChanged = subscriptions.single as VoidCallback;
    expect(
      tester
          .widget<DownloadsOngoingTab>(find.byType(DownloadsOngoingTab))
          .tasks,
      isEmpty,
    );

    when(() => downloads.tasks).thenReturn(const [_task]);
    onDownloadChanged();
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<DownloadsOngoingTab>(find.byType(DownloadsOngoingTab))
          .tasks,
      [_task],
    );

    await tester.pumpWidget(const SizedBox.shrink());
    verify(() => downloads.removeListener(onDownloadChanged)).called(1);
    expect(tester.takeException(), isNull);
  });
}

const _task = MangaDownloadTask(
  comicId: 'comic',
  title: 'Comic',
  subTitle: '',
  description: '',
  coverUrl: '',
  targets: [],
  completedEpIds: {},
  status: MangaDownloadTaskStatus.paused,
  createdAtMillis: 0,
  updatedAtMillis: 0,
);
