import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/downloads/downloads.dart';
import 'package:hazuki/app/service_locator.dart';
import 'package:hazuki/services/download_groups_service.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/services/manga_download/manga_download_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../support/test_service_locator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(const {});
    await ensureTestServiceLocator();
  });

  testWidgets('download tabs disable the edge overscroll indicator', (
    tester,
  ) async {
    final downloadService = MangaDownloadService();
    addTearDown(downloadService.dispose);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DownloadsPage(
          downloadService: downloadService,
          downloadGroupsService: sl<DownloadGroupsService>(),
          readerPageBuilder: (_, _) => const SizedBox.shrink(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final configuration = find.byKey(
      const ValueKey<String>('downloads_tab_scroll_configuration'),
    );
    expect(configuration, findsOneWidget);
    expect(
      find.descendant(
        of: configuration,
        matching: find.byType(StretchingOverscrollIndicator),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: configuration,
        matching: find.byType(GlowingOverscrollIndicator),
      ),
      findsNothing,
    );
  });

  testWidgets('bulk download actions prompt when there are no tasks', (
    tester,
  ) async {
    final downloadService = _FakeDownloadService();
    addTearDown(downloadService.dispose);

    await tester.pumpWidget(_downloadsPage(downloadService));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('No download tasks'), findsOneWidget);
    expect(downloadService.resumeAllCount, 0);

    await tester.tap(find.byIcon(Icons.pause_rounded));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('No download tasks'), findsOneWidget);
    expect(downloadService.pauseAllCount, 0);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('bulk download actions prompt after handling tasks', (
    tester,
  ) async {
    final downloadService = _FakeDownloadService(fakeTasks: const [_task]);
    addTearDown(downloadService.dispose);

    await tester.pumpWidget(_downloadsPage(downloadService));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('All download tasks started'), findsOneWidget);
    expect(downloadService.resumeAllCount, 1);

    await tester.tap(find.byIcon(Icons.pause_rounded));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('All download tasks paused'), findsOneWidget);
    expect(downloadService.pauseAllCount, 1);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('back exits multi-select before closing downloads page', (
    tester,
  ) async {
    final downloadService = MangaDownloadService();
    addTearDown(downloadService.dispose);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => DownloadsPage(
                        downloadService: downloadService,
                        downloadGroupsService: sl<DownloadGroupsService>(),
                        readerPageBuilder: (_, _) => const SizedBox.shrink(),
                      ),
                    ),
                  );
                },
                child: const Text('Open downloads'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open downloads'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Tab).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.checklist_rounded));
    await tester.pump();

    expect(find.byIcon(Icons.close_rounded), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pump();

    expect(find.byType(DownloadsPage), findsOneWidget);
    expect(find.byIcon(Icons.checklist_rounded), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.byType(DownloadsPage), findsNothing);
  });
}

Widget _downloadsPage(MangaDownloadService downloadService) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: DownloadsPage(
      downloadService: downloadService,
      downloadGroupsService: sl<DownloadGroupsService>(),
      readerPageBuilder: (_, _) => const SizedBox.shrink(),
    ),
  );
}

class _FakeDownloadService extends MangaDownloadService {
  _FakeDownloadService({this.fakeTasks = const []});

  final List<MangaDownloadTask> fakeTasks;
  int pauseAllCount = 0;
  int resumeAllCount = 0;

  @override
  List<MangaDownloadTask> get tasks => fakeTasks;

  @override
  Future<void> ensureInitialized() async {}

  @override
  Future<void> pauseAllTasks() async {
    pauseAllCount++;
  }

  @override
  Future<void> resumeAllTasks() async {
    resumeAllCount++;
  }
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
