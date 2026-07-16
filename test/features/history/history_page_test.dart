import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/app/service_locator.dart';
import 'package:hazuki/features/history/view/history_page.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/services/source/runtime/source_runtime_assembly.dart';
import 'package:hazuki/services/read_history_service.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/test_service_locator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(const {});
    await ensureTestServiceLocator();
    final sourceKey =
        sl<SourceRuntimeAssembly>().testing.runtime.activeSourceKey;
    await sl<ReadHistoryService>().importJsonList([
      {
        'id': 'comic-a',
        'title': 'Comic A',
        'sourceKey': sourceKey,
        'timestamp': 1,
      },
    ], replace: true);
  });

  tearDown(() async {
    await sl.reset();
  });

  testWidgets('shows a prompt when delete is tapped without a selection', (
    tester,
  ) async {
    await tester.pumpWidget(_buildApp());
    await _pumpUntilFound(tester, find.byIcon(Icons.checklist));

    await tester.tap(find.byIcon(Icons.checklist));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Select at least one comic to delete'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('system back exits selection mode before leaving history', (
    tester,
  ) async {
    await tester.pumpWidget(_buildApp());
    await _pumpUntilFound(tester, find.byIcon(Icons.checklist));

    await tester.tap(find.byIcon(Icons.checklist));
    await tester.pump();
    expect(find.byIcon(Icons.close), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pump();

    expect(find.text('History'), findsOneWidget);
    expect(find.byIcon(Icons.checklist), findsOneWidget);
    expect(find.byIcon(Icons.close), findsNothing);
  });
}

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 20 && finder.evaluate().isEmpty; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(finder, findsOneWidget);
}

Widget _buildApp() {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    initialRoute: '/history',
    routes: {
      '/': (_) => const Scaffold(body: Text('Home')),
      '/history': (_) => HistoryPage(
        readHistoryService: sl<ReadHistoryService>(),
        sourceService: sl<SourceSelectionGateway>(),
        imageGateway: sl<SourceImageGateway>(),
        comicDetailPageBuilder: (_, _) => const SizedBox.shrink(),
        onFavoriteRequested: (_, _) async {},
      ),
    },
  );
}
