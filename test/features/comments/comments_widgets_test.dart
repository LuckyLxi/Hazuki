import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/comments/view/comments_widgets.dart';
import 'package:hazuki/l10n/app_localizations.dart';

void main() {
  testWidgets('short multi-line comments still offer the expand toggle', (
    tester,
  ) async {
    final content = List.generate(8, (i) => 'line $i').join('<br>');
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CommentsSelectableContent(
            content: content,
            style: const TextStyle(fontSize: 14, height: 1.8),
            expansionKey: 'multi-line',
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
    final collapsedHeight = tester.getSize(find.byType(AnimatedSize)).height;

    await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byType(AnimatedSize)).height,
      greaterThan(collapsedHeight),
    );
  });
}
