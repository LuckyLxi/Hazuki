import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/settings/view/plugins/source_plugins_page.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/services/source/plugins/source_plugin_repository.dart';
import 'package:mocktail/mocktail.dart';

class _PluginGateway extends Mock implements SourcePluginGateway {}

void main() {
  testWidgets(
    'different plugins install independently and failures can retry',
    (tester) async {
      final gateway = _PluginGateway();
      final entries = [
        for (final id in ['slow', 'fast'])
          SourcePluginIndexEntry(
            id: id,
            name: id,
            version: '1.0.0',
            downloadUrl: Uri.parse('https://plugins.fixture.example/$id.js'),
          ),
      ];
      final slow = Completer<void>();
      final fast = Completer<void>();
      when(() => gateway.initialize()).thenAnswer((_) async {});
      when(() => gateway.installed).thenReturn([]);
      when(() => gateway.checkingIndex).thenReturn(false);
      when(() => gateway.indexError).thenReturn(null);
      when(() => gateway.availableUpdates).thenReturn([]);
      when(
        () => gateway.entriesFor(sourcePluginsRepositoryUrl),
      ).thenReturn(entries);
      when(() => gateway.pluginFor(any())).thenReturn(null);
      when(
        () => gateway.installFromRepository(
          sourcePluginsRepositoryUrl,
          entries[0],
        ),
      ).thenAnswer((_) => slow.future);
      when(
        () => gateway.installFromRepository(
          sourcePluginsRepositoryUrl,
          entries[1],
        ),
      ).thenAnswer((_) => fast.future);

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SourcePluginsPage(manager: gateway),
        ),
      );
      await tester.pumpAndSettle();
      final s = AppLocalizations.of(
        tester.element(find.byType(SourcePluginsPage)),
      )!;
      await tester.tap(find.widgetWithText(Tab, s.pluginsAvailable));
      await tester.pumpAndSettle();
      final buttons = find.widgetWithText(FilledButton, s.pluginsInstall);
      await tester.tap(buttons.at(0));
      await tester.pump();
      expect(tester.widget<FilledButton>(buttons.at(0)).onPressed, isNull);
      expect(tester.widget<FilledButton>(buttons.at(1)).onPressed, isNotNull);
      await tester.tap(buttons.at(0));
      await tester.tap(buttons.at(1));
      await tester.pump();
      verify(
        () => gateway.installFromRepository(
          sourcePluginsRepositoryUrl,
          entries[0],
        ),
      ).called(1);
      verify(
        () => gateway.installFromRepository(
          sourcePluginsRepositoryUrl,
          entries[1],
        ),
      ).called(1);
      expect(tester.widget<FilledButton>(buttons.at(1)).onPressed, isNull);

      fast.completeError(StateError('fast download failed'));
      await tester.pump();
      expect(find.textContaining('fast download failed'), findsOneWidget);
      expect(find.byIcon(Icons.tips_and_updates_rounded), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.widget<FilledButton>(buttons.at(0)).onPressed, isNull);
      expect(tester.widget<FilledButton>(buttons.at(1)).onPressed, isNotNull);
      when(
        () => gateway.installFromRepository(
          sourcePluginsRepositoryUrl,
          entries[1],
        ),
      ).thenAnswer((_) async {});
      await tester.tap(buttons.at(1));
      await tester.pump();
      verify(
        () => gateway.installFromRepository(
          sourcePluginsRepositoryUrl,
          entries[1],
        ),
      ).called(1);
      slow.complete();
      await tester.pumpAndSettle();
      expect(find.byType(LinearProgressIndicator), findsNothing);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
