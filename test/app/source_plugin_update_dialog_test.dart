import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/app/source_runtime/source_plugin_update_dialog_support.dart';
import 'package:hazuki/features/settings/view/plugins/source_plugins_page.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/services/source/source_capabilities.dart';

class _Plugins extends ChangeNotifier implements SourcePluginGateway {
  List<SourcePluginUpdate> updates = [];
  int checks = 0;
  final installedUpdates = <String>[];
  final installRepositories = <String>[];
  Future<void> Function()? install;
  @override
  String? indexError;
  @override
  List<SourcePluginUpdate> get availableUpdates => updates;
  @override
  List<InstalledSourcePlugin> get installed =>
      updates.map((update) => update.plugin).toList();
  @override
  List<String> get repositories => [];
  @override
  Map<String, String> get errors => {};
  @override
  bool get checkingIndex => false;
  @override
  Future<void> initialize() async {}
  @override
  List<SourcePluginIndexEntry> entriesFor(String repository) =>
      updates.map((update) => update.entry).toList();
  @override
  InstalledSourcePlugin? pluginFor(String id) =>
      installed.where((plugin) => plugin.manifest.id == id).firstOrNull;
  @override
  Future<void> checkStartupUpdates() async => checks++;
  @override
  Future<void> installFromRepository(
    String repository,
    SourcePluginIndexEntry entry,
  ) async {
    installedUpdates.add(entry.id);
    installRepositories.add(repository);
    await install?.call();
    updates.removeWhere((update) => update.entry.id == entry.id);
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

SourcePluginUpdate _update(
  String id, {
  bool edited = false,
  String? repository,
}) => SourcePluginUpdate(
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
    repository: repository,
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

  Future<void> pumpApp(WidgetTester tester, {String locale = 'en'}) =>
      tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          locale: Locale(locale),
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

  for (final dismissal in ['details', 'barrier', 'back', 'update']) {
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
        case 'details':
          await tester.tap(find.text('View details'));
        case 'update':
          await tester.tap(find.text('Update'));
        case 'barrier':
          await tester.tapAt(const Offset(5, 5));
        case 'back':
          await tester.binding.handlePopRoute();
      }
      await tester.pump();
      if (dismissal == 'update') await tester.pump();
      await tester.pump(const Duration(milliseconds: 140));
      expect(dialog, findsOneWidget);
      expect(opacity(), inExclusiveRange(0, 1));
      expect(size(), inExclusiveRange(0.98, 1));
      expect(offset(), inExclusiveRange(0, 0.02));
      await tester.pumpAndSettle();
      await pending;
      expect(dialog, findsNothing);
      expect(plugins.installedUpdates, dismissal == 'update' ? ['a'] : isEmpty);
      if (dismissal == 'details') {
        final page = find.byType(SourcePluginsPage);
        expect(page, findsOneWidget);
        expect(
          DefaultTabController.of(tester.element(find.byType(TabBar))).index,
          SourcePluginsTab.market.index,
        );
        expect(find.text('Plugin market'), findsOneWidget);
        expect(find.byType(FilledButton).hitTestable(), findsOneWidget);
        navigator.currentState!.pop();
        await tester.pumpAndSettle();
        expect(find.text('Home'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final locale in ['en', 'zh']) {
    for (final count in [1, 2, 3]) {
      testWidgets(
        'startup summarizes $count updates in $locale without installing',
        (tester) async {
          plugins.updates = [for (var i = 0; i < count; i++) _update('$i')];
          await pumpApp(tester, locale: locale);
          final pending = showUpdates();
          await tester.pumpAndSettle();
          expect(plugins.checks, 1);
          final s = AppLocalizations.of(
            tester.element(find.byType(SourcePluginUpdateDialog)),
          )!;
          expect(
            find.text(
              count == 1
                  ? s.pluginsUpdateAvailable('Plugin 0')
                  : s.pluginsUpdatesMessage(count),
            ),
            findsOneWidget,
          );
          if (locale == 'zh') {
            expect(
              find.text(count == 1 ? 'Plugin 0 有新版本' : '有 $count 个插件有新版本'),
              findsOneWidget,
            );
            expect(s.pluginsAvailable, '插件市场');
          }
          expect(find.byType(TextButton), findsOneWidget);
          expect(find.byType(FilledButton), findsOneWidget);
          expect(find.text('1.0.0 → 2.0.0'), findsNothing);
          expect(plugins.installedUpdates, isEmpty);
          await tester.tapAt(const Offset(5, 5));
          await tester.pumpAndSettle();
          await pending;
          expect(plugins.installedUpdates, isEmpty);
          expect(refreshes, 0);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

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
        plugins.updates = [
          _update('a', edited: true),
          _update('b', edited: true),
          _update('c'),
        ];
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
          await tester.tapAt(const Offset(5, 5));
          await tester.pumpAndSettle();
        } else {
          expect(plugins.installedUpdates, ['a', 'b', 'c']);
          expect(refreshes, 3);
        }
        await pending;
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('update installs every plugin from its own repository', (
    tester,
  ) async {
    const repository = 'https://plugins.example/custom.json';
    plugins.updates = [_update('a'), _update('b', repository: repository)];
    await pumpApp(tester);
    final pending = showUpdates();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Update'));
    await tester.pumpAndSettle();
    await pending;
    expect(plugins.installedUpdates, ['a', 'b']);
    expect(plugins.installRepositories.last, repository);
    expect(plugins.updates, isEmpty);
    expect(refreshes, 2);
    expect(find.byType(SourcePluginUpdateDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'batch continues after a failure and retries only failed plugins',
    (tester) async {
      plugins.updates = [_update('a'), _update('b'), _update('c')];
      plugins.install = () async {
        if (plugins.installedUpdates.last == 'b') {
          throw StateError('Download failed');
        }
      };
      await pumpApp(tester);
      final pending = showUpdates();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Update'));
      await tester.pumpAndSettle();
      expect(plugins.installedUpdates, ['a', 'b', 'c']);
      expect(plugins.updates.map((update) => update.entry.id), ['b']);
      expect(
        find.textContaining('Plugin b: Bad state: Download failed'),
        findsOneWidget,
      );
      expect(
        find.text('A new version is available for Plugin b'),
        findsOneWidget,
      );
      expect(refreshes, 2);
      plugins.install = null;
      await tester.tap(find.text('Update'));
      await tester.pumpAndSettle();
      await pending;
      expect(plugins.installedUpdates, ['a', 'b', 'c', 'b']);
      expect(refreshes, 3);
      expect(find.byType(SourcePluginUpdateDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('dialog smoothly resizes for progress, errors and retry', (
    tester,
  ) async {
    plugins.updates = [_update('a')];
    final download = Completer<void>();
    plugins.install = () => download.future;
    await pumpApp(tester);
    final showing = showUpdates();
    await tester.pumpAndSettle();
    final surface = find
        .descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(Material),
        )
        .first;
    double height() => tester.getSize(surface).height;
    final initialHeight = height();

    await tester.tap(find.text('Update'));
    await tester.pump();
    expect(height(), closeTo(initialHeight, 0.01));
    await tester.pump(const Duration(milliseconds: 140));
    final expandingHeight = height();
    await tester.pump(const Duration(milliseconds: 140));
    final progressHeight = height();
    expect(expandingHeight, inExclusiveRange(initialHeight, progressHeight));

    download.completeError(
      StateError('Download failed\nPlease try again\nConnection interrupted'),
    );
    await tester.pump();
    expect(height(), closeTo(progressHeight, 0.01));
    await tester.pumpAndSettle();
    final errorHeight = height();
    expect(errorHeight, greaterThan(progressHeight));

    final retry = Completer<void>();
    plugins.install = () => retry.future;
    await tester.tap(find.text('Update'));
    await tester.pump();
    expect(height(), closeTo(errorHeight, 0.01));
    await tester.pump(const Duration(milliseconds: 140));
    expect(height(), inExclusiveRange(progressHeight, errorHeight));
    await tester.pump(const Duration(milliseconds: 140));
    expect(height(), closeTo(progressHeight, 0.01));
    retry.complete();
    await tester.pumpAndSettle();
    await showing;
    expect(find.byType(SourcePluginUpdateDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

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
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'View details'))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Update'))
            .onPressed,
        isNull,
      );
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(SourcePluginUpdateDialog), findsOneWidget);
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
