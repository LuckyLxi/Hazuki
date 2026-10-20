import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/shared/source_interaction/source_animated_dialog.dart';

void main() {
  Future<BuildContext> mount(
    WidgetTester tester, {
    bool disableAnimations = false,
  }) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: disableAnimations),
          child: child!,
        ),
        home: Builder(
          builder: (value) {
            context = value;
            return const Scaffold(body: Text('Home'));
          },
        ),
      ),
    );
    return context;
  }

  const dialog = AlertDialog(title: Text('Plugin dialog'));
  Finder transition(Type type) => find
      .ancestor(of: find.byType(AlertDialog), matching: find.byType(type))
      .first;

  testWidgets('plugin dialogs animate in and retain content while closing', (
    tester,
  ) async {
    final context = await mount(tester);
    final closing = showSourceAnimatedDialog<void>(context, child: dialog);
    await tester.pump();
    double scale() =>
        tester.widget<ScaleTransition>(transition(ScaleTransition)).scale.value;
    double opacity() =>
        tester.widget<FadeTransition>(transition(FadeTransition)).opacity.value;
    expect(scale(), closeTo(0.9, 0.001));
    expect(opacity(), 0);
    await tester.pump(const Duration(milliseconds: 70));
    expect(scale(), greaterThan(0.9));
    expect(opacity(), inExclusiveRange(0, 1));
    expect(
      tester
          .widget<SlideTransition>(transition(SlideTransition))
          .position
          .value
          .dy,
      greaterThan(0),
    );
    await tester.pump(const Duration(milliseconds: 210));
    await tester.pumpAndSettle();
    expect(scale(), 1);
    expect(opacity(), 1);
    Navigator.of(context, rootNavigator: true).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.text('Plugin dialog'), findsOneWidget);
    expect(scale(), inExclusiveRange(0.9, 1));
    expect(opacity(), inExclusiveRange(0, 1));
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pumpAndSettle();
    await closing;
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Home'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('closing during entry continues from the current animation', (
    tester,
  ) async {
    final context = await mount(tester);
    final closing = showSourceAnimatedDialog<void>(context, child: dialog);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    final before = tester
        .widget<ScaleTransition>(transition(ScaleTransition))
        .scale
        .value;
    Navigator.of(context, rootNavigator: true).pop();
    await tester.pump();
    final reversed = tester
        .widget<ScaleTransition>(transition(ScaleTransition))
        .scale
        .value;
    expect(reversed, closeTo(before, 0.001));
    await tester.pumpAndSettle();
    await closing;
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('plugin dialogs honor the system disable animations setting', (
    tester,
  ) async {
    final context = await mount(tester, disableAnimations: true);
    unawaited(showSourceAnimatedDialog<void>(context, child: dialog));
    await tester.pump();
    expect(
      tester.widget<ScaleTransition>(transition(ScaleTransition)).scale.value,
      1,
    );
    Navigator.of(context, rootNavigator: true).pop();
    await tester.pump();
    await tester.pump();
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
