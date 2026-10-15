import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/settings/view/plugins/source_plugins_page.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/services/source/plugins/source_plugin_repository.dart';
import 'package:hazuki/widgets/hazuki_m3e_loading_indicator.dart';
import 'package:mocktail/mocktail.dart';

class _PluginGateway extends Mock implements SourcePluginGateway {}

void main() {
  testWidgets('market updates animate the loader in and out without resizing', (
    tester,
  ) async {
    final gateway = _PluginGateway();
    const plugin = InstalledSourcePlugin(
      manifest: SourcePluginManifest(
        id: 'example',
        name: 'Example',
        version: '1.0.0',
        apiVersion: 1,
        entry: 'main.js',
      ),
      directory: 'example',
      repository: sourcePluginsRepositoryUrl,
    );
    final entry = SourcePluginIndexEntry(
      id: 'example',
      name: 'Example',
      version: '2.0.0',
      downloadUrl: Uri.parse('https://plugins.fixture.example/example.js'),
    );
    final updates = [
      SourcePluginUpdate(plugin: plugin, entry: entry, localVersion: '1.0.0'),
    ];
    final pending = Completer<void>();
    when(gateway.initialize).thenAnswer((_) async {});
    when(() => gateway.installed).thenReturn([plugin]);
    when(() => gateway.checkingIndex).thenReturn(false);
    when(() => gateway.indexError).thenReturn(null);
    when(() => gateway.availableUpdates).thenAnswer((_) => updates);
    when(
      () => gateway.entriesFor(sourcePluginsRepositoryUrl),
    ).thenReturn([entry]);
    when(() => gateway.pluginFor('example')).thenReturn(plugin);
    when(
      () => gateway.installFromRepository(sourcePluginsRepositoryUrl, entry),
    ).thenAnswer((_) async {
      await pending.future;
      updates.clear();
    });
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SourcePluginsPage(
          manager: gateway,
          initialTab: SourcePluginsTab.market,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final button = find.byKey(const ValueKey('plugin-market-action-example'));
    final originalSize = tester.getSize(button);
    final loader = find.descendant(
      of: button,
      matching: find.byType(HazukiM3ELoadingIndicator),
    );
    double opacity() => tester
        .widget<FadeTransition>(
          find
              .ancestor(of: loader, matching: find.byType(FadeTransition))
              .first,
        )
        .opacity
        .value;
    double scale() => tester
        .widget<ScaleTransition>(
          find
              .ancestor(of: loader, matching: find.byType(ScaleTransition))
              .first,
        )
        .scale
        .value;
    expect(find.widgetWithText(FilledButton, '更新'), findsOneWidget);
    await tester.tap(button);
    await tester.pump();
    expect(opacity(), 0);
    expect(scale(), 0.8);
    await tester.pump(const Duration(milliseconds: 100));
    expect(opacity(), inExclusiveRange(0, 1));
    expect(scale(), inExclusiveRange(0.8, 1));
    expect(tester.getSize(button), originalSize);
    await tester.pump(const Duration(milliseconds: 100));
    expect(opacity(), 1);
    expect(scale(), 1);
    expect(tester.getSize(button), originalSize);
    expect(
      find.descendant(
        of: button,
        matching: find.byType(HazukiM3ELoadingIndicator),
      ),
      findsOneWidget,
    );
    expect(find.byType(LinearProgressIndicator), findsNothing);
    pending.complete();
    await tester.pump();
    final completedSize = tester.getSize(button);
    expect(loader, findsOneWidget);
    expect(opacity(), 1);
    await tester.pump(const Duration(milliseconds: 100));
    expect(opacity(), inExclusiveRange(0, 1));
    expect(scale(), inExclusiveRange(0.8, 1));
    expect(tester.getSize(button), completedSize);
    await tester.pumpAndSettle();
    expect(find.byType(HazukiM3ELoadingIndicator), findsNothing);
    expect(find.widgetWithText(FilledButton, '已安装'), findsOneWidget);
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    expect(tester.takeException(), isNull);
  });

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
      final slowButton = find.byKey(
        const ValueKey('plugin-market-action-slow'),
      );
      final fastButton = find.byKey(
        const ValueKey('plugin-market-action-fast'),
      );
      final initialButtonSize = tester.getSize(slowButton);
      final initialRowPosition = tester.getTopLeft(find.text('slow'));
      await tester.tap(slowButton);
      await tester.pump();
      expect(tester.widget<FilledButton>(slowButton).onPressed, isNull);
      expect(tester.widget<FilledButton>(fastButton).onPressed, isNotNull);
      expect(tester.getSize(slowButton), initialButtonSize);
      expect(tester.getTopLeft(find.text('slow')), initialRowPosition);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(
        find.descendant(
          of: slowButton,
          matching: find.byType(HazukiM3ELoadingIndicator),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: fastButton,
          matching: find.byType(HazukiM3ELoadingIndicator),
        ),
        findsNothing,
      );
      await tester.tap(slowButton);
      await tester.tap(fastButton);
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
      expect(tester.widget<FilledButton>(fastButton).onPressed, isNull);
      expect(find.byType(HazukiM3ELoadingIndicator), findsNWidgets(2));
      await tester.pump(const Duration(milliseconds: 200));

      fast.completeError(StateError('fast download failed'));
      await tester.pump();
      expect(find.textContaining('fast download failed'), findsOneWidget);
      expect(find.byIcon(Icons.tips_and_updates_rounded), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.widget<FilledButton>(slowButton).onPressed, isNull);
      expect(tester.widget<FilledButton>(fastButton).onPressed, isNotNull);
      expect(find.byType(HazukiM3ELoadingIndicator), findsNWidgets(2));
      for (var frame = 0; frame < 20; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(find.byType(HazukiM3ELoadingIndicator), findsOneWidget);
      when(
        () => gateway.installFromRepository(
          sourcePluginsRepositoryUrl,
          entries[1],
        ),
      ).thenAnswer((_) async {});
      await tester.tap(fastButton);
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
      expect(find.byType(HazukiM3ELoadingIndicator), findsNothing);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
