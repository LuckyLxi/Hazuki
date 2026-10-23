import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/settings/view/translation/translation_usage_group.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/services/translation/translation_usage_store.dart';

class _Usage extends TranslationUsageStore {
  bool cleared = false;
  @override
  Future<Map<String, DailyTranslationUsage>> load() async => cleared
      ? {}
      : {
          TranslationUsageStore.dateKey(
            DateTime.now(),
          ): const DailyTranslationUsage(
            pages: 3,
            requests: 4,
            inputTokens: 12,
            outputTokens: 5,
          ),
        };
  @override
  Future<void> clear() async {
    cleared = true;
    notifyListeners();
  }
}

void main() {
  for (final width in [320.0, 960.0]) {
    testWidgets(
      'usage summary and heatmap fit width $width and reveal daily usage',
      (tester) async {
        final usage = _Usage();
        addTearDown(usage.dispose);
        tester.view.physicalSize = Size(width, 500);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: Scaffold(body: TranslationUsageGroup(store: usage)),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Last 30 days: 3 pages · 17 tokens'), findsOneWidget);
        final heatmap = find.byWidgetPredicate(
          (widget) =>
              widget is CustomPaint &&
              widget.painter.runtimeType.toString() == '_HeatmapPainter',
        );
        final bounds = tester.getRect(heatmap);
        expect(bounds.width / 15, lessThanOrEqualTo(52));
        await tester.tapAt(
          Offset(
            bounds.right - 9,
            bounds.top + (DateTime.now().weekday - 1) * 15 + 6,
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.textContaining(
            '3 pages · 4 requests · 12 input tokens · 5 output tokens',
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('clearing usage requires confirmation and updates the summary', (
    tester,
  ) async {
    final usage = _Usage();
    addTearDown(usage.dispose);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(body: TranslationUsageGroup(store: usage)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear statistics'));
    await tester.pumpAndSettle();
    expect(usage.cleared, isFalse);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(usage.cleared, isFalse);
    await tester.tap(find.text('Clear statistics'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(usage.cleared, isTrue);
    expect(find.text('Last 30 days: 0 pages · 0 tokens'), findsOneWidget);
  });
}
