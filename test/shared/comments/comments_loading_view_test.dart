import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loading_indicator_m3e/loading_indicator_m3e.dart';

import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/shared/comments/comments_loading_view.dart';
import 'package:hazuki/widgets/sticker_loading_indicator.dart';

void main() {
  testWidgets('comments initial loading uses the M3E indicator', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: CommentsInitialLoadingView()),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('comments-initial-loading')),
      findsOneWidget,
    );
    expect(find.byType(LoadingIndicatorM3E), findsOneWidget);
    expect(find.byType(HazukiSandyLoadingIndicator), findsNothing);
  });
}
