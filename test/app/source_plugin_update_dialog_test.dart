import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/app/source_runtime/source_plugin_update_dialog_support.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/services/source/source_capabilities.dart';

class _Plugins extends ChangeNotifier implements SourcePluginGateway {
  List<SourcePluginUpdate> updates = [];
  int checks = 0;
  final installedUpdates = <String>[];
  Future<void> Function()? install;
  @override
  String? indexError;
  @override
  List<SourcePluginUpdate> get availableUpdates => updates;
  @override
  Future<void> checkStartupUpdates() async => checks++;
  @override
  Future<void> installFromRepository(
    String repository,
    SourcePluginIndexEntry entry,
  ) async {
    installedUpdates.add(entry.id);
    await install?.call();
    updates.removeWhere((update) => update.entry.id == entry.id);
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

SourcePluginUpdate _update(String id, {bool edited = false}) =>
    SourcePluginUpdate(
      plugin: InstalledSourcePlugin(
        manifest: SourcePluginManifest(
          id: id,
          name: 'Plugin $id',
          version: '1.0.0',
          apiVersion: 1,
          entry: 'main.js',
        ),
        directory: id,
        customEdited: edited,
      ),
      entry: SourcePluginIndexEntry(
        id: id,
        name: 'Plugin $id',
        version: '2.0.0',
        downloadUrl: Uri.parse('https://downloads.example/$id.js'),
      ),
      localVersion: '1.0.0',
    );

void main() {
  late _Plugins plugins;
  late GlobalKey<NavigatorState> navigator;
  var refreshes = 0;
  setUp(() {
    plugins = _Plugins();
    navigator = GlobalKey<NavigatorState>();
    refreshes = 0;
  });
  tearDown(() => plugins.dispose());

  Future<void> pumpApp(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      navigatorKey: navigator,
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: Text('Home')),
    ),
  );

  Future<void> showUpdates() =>
      SourcePluginUpdateDialogSupport(gateway: plugins).showIfNeeded(
        navigatorKey: navigator,
        isMounted: () => true,
        onUpdated: () => refreshes++,
      );

  for (final dismissal in ['cancel', 'barrier', 'back']) {
    testWidgets('dialog animates opening and $dismissal dismissal', (
      tester,
    ) async {
      plugins.updates = [_update('a')];
      await pumpApp(tester);
      final pending = showUpdates();
      await tester.pump();

      final dialog = find.byType(SourcePluginUpdateDialog);
      final fade = find.ancestor(
        of: dialog,
        matching: find.byType(FadeTransition),
      );
      final scale = find.ancestor(
        of: dialog,
        matching: find.byType(ScaleTransition),
      );
      final slide = find.ancestor(
        of: dialog,
        matching: find.byType(SlideTransition),
      );
      double opacity() => tester.widget<FadeTransition>(fade).opacity.value;
      double size() => tester.widget<ScaleTransition>(scale).scale.value;
      double offset() =>
          tester.widget<SlideTransition>(slide).position.value.dy;

      expect(opacity(), 0);
      expect(size(), closeTo(0.98, 0.001));
      expect(offset(), closeTo(0.02, 0.001));
      await tester.pump(const Duration(milliseconds: 140));
      expect(opacity(), inExclusiveRange(0, 1));
      expect(size(), inExclusiveRange(0.98, 1));
      expect(offset(), inExclusiveRange(0, 0.02));
      await tester.pumpAndSettle();
      expect(opacity(), 1);
      expect(size(), 1);
      expect(offset(), 0);

      switch (dismissal) {
        case 'cancel':
          await tester.tap(find.text('Cancel'));
        case 'barrier':
          await tester.tapAt(const Offset(5, 5));
        case 'back':
          await tester.binding.handlePopRoute();
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 140));
      expect(dialog, findsOneWidget);
      expect(opacity(), inExclusiveRange(0, 1));
      expect(size(), inExclusiveRange(0.98, 1));
      expect(offset(), inExclusiveRange(0, 0.02));
      await tester.pumpAndSettle();
      await pending;
      expect(dialog, findsNothing);
      expect(plugins.installedUpdates, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'startup dialog lists all installed updates and cancellation never installs',
    (tester) async {
      plugins.updates = [_update('a'), _update('b')];
      await pumpApp(tester);
      final pending = showUpdates();
      await tester.pumpAndSettle();
      expect(plugins.checks, 1);
      expect(find.text('Plugin a'), findsOneWidget);
      expect(find.text('Plugin b'), findsOneWidget);
      expect(find.text('1.0.0 → 2.0.0'), findsNWidgets(2));
      expect(plugins.installedUpdates, isEmpty);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await pending;
      expect(plugins.installedUpdates, isEmpty);
      expect(refreshes, 0);
      expect(tester.takeException(), isNull);
    },
  );

  for (final hasError in [false, true]) {
    testWidgets(
      'startup avoids a dialog for ${hasError ? 'an index failure' : 'no updates'}',
      (tester) async {
        if (hasError) {
          plugins.updates = [_update('a')];
          plugins.indexError = 'Offline';
        }
        await pumpApp(tester);
        await showUpdates();
        await tester.pumpAndSettle();
        expect(plugins.checks, 1);
        expect(find.byType(SourcePluginUpdateDialog), findsNothing);
        expect(plugins.installedUpdates, isEmpty);
      },
    );
  }

  for (final confirm in [false, true]) {
    testWidgets(
      'startup updates confirm replacing edited scripts (confirm: $confirm)',
      (tester) async {
        plugins.updates = [_update('a', edited: true)];
        await pumpApp(tester);
        final pending = showUpdates();
        await tester.pumpAndSettle();
        await tester.tap(find.text('Update'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(
          find.text(
            'Update replaces your edited script. The old package is kept as a backup.',
          ),
          findsOneWidget,
        );
        expect(plugins.installedUpdates, isEmpty);
        await tester.tap(find.text(confirm ? 'OK' : 'Cancel').last);
        await tester.pumpAndSettle();
        if (!confirm) {
          expect(plugins.installedUpdates, isEmpty);
          await tester.tap(find.text('Cancel'));
          await tester.pumpAndSettle();
        } else {
          expect(plugins.installedUpdates, ['a']);
          expect(refreshes, 1);
        }
        await pending;
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'failed updates stay available for retry and pending downloads cannot dismiss',
    (tester) async {
      plugins.updates = [_update('a')];
      plugins.install = () async => throw StateError('Download failed');
      await pumpApp(tester);
      final showing = showUpdates();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Update'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Download failed'), findsOneWidget);
      expect(plugins.updates, hasLength(1));
      final download = Completer<void>();
      plugins.install = () => download.future;
      await tester.tap(find.text('Update'));
      await tester.pump();
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      await tester.tapAt(const Offset(5, 5));
      await tester.pump();
      expect(find.byType(SourcePluginUpdateDialog), findsOneWidget);
      download.complete();
      await tester.pumpAndSettle();
      await showing;
      expect(plugins.installedUpdates, ['a', 'a']);
      expect(refreshes, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
