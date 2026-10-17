import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/shared/liquid_glass_support.dart';
import 'package:hazuki/shared/source_account/source_account_actions.dart';

class _MockSourceSwitchGateway extends Mock implements SourceSwitchGateway {}

Future<_MockSourceSwitchGateway> _openPicker(
  WidgetTester tester, {
  required int sourceCount,
  String activeSourceKey = 'source_1',
  double textScale = 1,
}) async {
  final gateway = _MockSourceSwitchGateway();
  when(() => gateway.activeSourceKey).thenReturn(activeSourceKey);
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
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
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
  for (final glassEnabled in [false, true]) {
    group('liquid glass enabled=$glassEnabled', () {
      _sourceSwitchDialogTests(glassEnabled);
    });
  }
}

void _sourceSwitchDialogTests(bool glassEnabled) {
  setUp(() => HazukiLiquidGlass.initialize(enabled: glassEnabled));
  tearDown(() => HazukiLiquidGlass.setEnabled(false));

  testWidgets('picker follows the glass setting while open', (tester) async {
    await _openPicker(tester, sourceCount: 3);
    final surface = find.byKey(
      const ValueKey('home-source-switch-liquid-glass-surface'),
    );
    expect(surface, glassEnabled ? findsOneWidget : findsNothing);
    final listSize = tester.getSize(find.byType(ListView));
    await tester.runAsync(() => HazukiLiquidGlass.setEnabled(!glassEnabled));
    await tester.pumpAndSettle();
    expect(surface, glassEnabled ? findsNothing : findsOneWidget);
    expect(tester.getSize(find.byType(ListView)), listSize);
    expect(find.text('Source 1').hitTestable(), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  for (final textScale in [1.0, 2.0]) {
    testWidgets(
      'picker reveals and focuses a late current source at ${textScale}x text',
      (tester) async {
        await _openPicker(
          tester,
          sourceCount: 30,
          activeSourceKey: 'source_28',
          textScale: textScale,
        );
        final current = find.widgetWithText(ListTile, 'Source 28');
        final list = find.byType(ListView);
        expect(current.hitTestable(), findsOneWidget);
        final listBounds = tester.getRect(list);
        final itemBounds = tester.getRect(current);
        expect(itemBounds.top, greaterThanOrEqualTo(listBounds.top - 0.01));
        expect(itemBounds.bottom, lessThanOrEqualTo(listBounds.bottom + 0.01));
        expect(Focus.of(tester.element(current)).hasPrimaryFocus, isTrue);
        await tester.drag(list, const Offset(0, 300));
        await tester.pumpAndSettle();
        expect(find.text('Source 28').hitTestable(), findsNothing);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(current.hitTestable(), findsOneWidget);
        expect(Focus.of(tester.element(current)).hasPrimaryFocus, isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('picker handles a current source absent from the list', (
    tester,
  ) async {
    await _openPicker(tester, sourceCount: 5, activeSourceKey: 'missing');
    expect(find.text('Source 1').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

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
