import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/reader/view/reader_windows_shortcuts_dialog.dart';
import 'package:hazuki/l10n/app_localizations.dart';

void main() {
  testWidgets('Windows shortcuts dialog explains reopening and animates out', (
    tester,
  ) async {
    final dialogTheme = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
    );
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => unawaited(
              showReaderWindowsShortcutsDialog(context, theme: dialogTheme),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('reader-windows-shortcuts-fade')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('reader-windows-shortcuts-scale')),
      findsOneWidget,
    );
    await tester.pumpAndSettle();

    expect(find.text('Windows reader shortcuts'), findsOneWidget);
    expect(find.textContaining('Reading settings'), findsOneWidget);
    expect(find.textContaining('Alt'), findsWidgets);
    final shortcutIcon = tester.widget<Icon>(
      find.byIcon(Icons.keyboard_alt_outlined),
    );
    expect(shortcutIcon.color, dialogTheme.colorScheme.primary);

    await tester.tap(find.text('Close'));
    await tester.pump();
    expect(find.text('Windows reader shortcuts'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('Windows reader shortcuts'), findsNothing);
  });
}
