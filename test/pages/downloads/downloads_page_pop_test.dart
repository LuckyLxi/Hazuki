import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/downloads/downloads.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/services/manga_download/manga_download_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(const {});
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
