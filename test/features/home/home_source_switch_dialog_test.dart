import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/shared/source_account/source_account_actions.dart';

class _MockSourceSwitchGateway extends Mock implements SourceSwitchGateway {}

Future<_MockSourceSwitchGateway> _openPicker(
  WidgetTester tester, {
  required int sourceCount,
}) async {
  final gateway = _MockSourceSwitchGateway();
  when(() => gateway.activeSourceKey).thenReturn('source_1');
  when(() => gateway.allowedSources).thenReturn([
    for (var index = 1; index <= sourceCount; index++)
      SourceCatalogEntry(
        key: 'source_$index',
        name: 'Source $index',
        fileName: 'source_$index.js',
      ),
  ]);
  when(() => gateway.loadActiveSourcePreference()).thenAnswer((_) async {});

  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () =>
                showHomeSourceSwitchDialog(context, sourceService: gateway),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
  return gateway;
}

void main() {
  for (final sourceCount in [1, 3]) {
    testWidgets('picker fits $sourceCount sources without scrolling', (
      tester,
    ) async {
      await _openPicker(tester, sourceCount: sourceCount);

      expect(find.byType(ListTile), findsNWidgets(sourceCount));
      final scrollable = tester.state<ScrollableState>(
        find.descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        ),
      );
      expect(scrollable.position.maxScrollExtent, 0);
      expect(
        tester.getSize(find.byType(ListView)).height,
        sourceCount * (tester.getSize(find.byType(ListTile).first).height + 6),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('picker shows three sources and scrolls to select more', (
    tester,
  ) async {
    final gateway = await _openPicker(tester, sourceCount: 5);
    when(
      () => gateway.hasLocalSourceFile('source_5'),
    ).thenAnswer((_) async => true);
    when(() => gateway.activateSource('source_5')).thenAnswer((_) async {});
    when(
      () => gateway.ensureInitialized(sourceKey: 'source_5'),
    ).thenAnswer((_) async {});

    expect(
      tester.getSize(find.byType(ListView)).height,
      3 * (tester.getSize(find.byType(ListTile).first).height + 6),
    );
    expect(find.text('Source 3').hitTestable(), findsOneWidget);
    expect(find.text('Source 4').hitTestable(), findsNothing);
    final cancelPosition = tester.getTopLeft(find.text('Cancel'));

    await tester.drag(find.byType(ListView), const Offset(0, -200));
    await tester.pumpAndSettle();

    expect(find.text('Source 5').hitTestable(), findsOneWidget);
    expect(tester.getTopLeft(find.text('Cancel')), cancelPosition);
    await tester.tap(find.text('Source 5'));
    await tester.pumpAndSettle();

    verify(() => gateway.activateSource('source_5')).called(1);
    verify(() => gateway.ensureInitialized(sourceKey: 'source_5')).called(1);
    expect(find.byType(Dialog), findsNothing);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('picker list shrinks to fit a short window', (tester) async {
    tester.view.physicalSize = const Size(800, 350);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _openPicker(tester, sourceCount: 5);

    expect(tester.takeException(), isNull);
    expect(find.text('Cancel').hitTestable(), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(find.text('Source 5').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
