import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/settings/view/translation/translation_usage_group.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/services/translation/translation_usage_store.dart';
import 'package:intl/intl.dart';

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
        final now = DateTime.now();
        expect(find.text(DateFormat.yMMMEd('en').format(now)), findsOneWidget);
        for (final (label, value) in [
          ('Pages', '3'),
          ('Requests', '4'),
          ('Input tokens', '12'),
          ('Output tokens', '5'),
        ]) {
          expect(
            find.descendant(
              of: find.ancestor(
                of: find.text(label),
                matching: find.byType(Row),
              ),
              matching: find.text(value),
            ),
            findsOneWidget,
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('tapping another cell switches the detail immediately', (
    tester,
  ) async {
    final usage = _Usage();
    addTearDown(usage.dispose);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: ListView(children: [TranslationUsageGroup(store: usage)]),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final bounds = tester.getRect(
      find.byWidgetPredicate(
        (widget) =>
            widget is CustomPaint &&
            widget.painter.runtimeType.toString() == '_HeatmapPainter',
      ),
    );
    final now = DateTime.now();
    Offset cell(int daysAgo) {
      final row = now.weekday - 1 - daysAgo;
      return Offset(
        bounds.right - 9 + (row < 0 ? -15 : 0),
        bounds.top + (row % 7) * 15 + 6,
      );
    }

    final today = find.text(DateFormat.yMMMEd('en').format(now));
    final earlier = find.text(
      DateFormat.yMMMEd(
        'en',
      ).format(DateTime(now.year, now.month, now.day - 1)),
    );
    await tester.tapAt(cell(0));
    await tester.pumpAndSettle();
    expect(today, findsOneWidget);

    // 不等待收起动画，下一帧就应换成新格子的详情。
    await tester.tapAt(cell(1));
    await tester.pump();
    expect(today, findsNothing);
    expect(earlier, findsOneWidget);

    await tester.tapAt(cell(1));
    await tester.pumpAndSettle();
    expect(earlier, findsNothing);
  });

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
