import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/settings/view/plugins/source_plugins_page.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/services/source/plugins/source_plugin_repository.dart';
import 'package:hazuki/shared/preferences/software_update_source.dart';
import 'package:mocktail/mocktail.dart';

class _MockPlugins extends Mock implements SourcePluginGateway {}

const _repository = sourcePluginsRepositoryUrl;

const _installed = [
  InstalledSourcePlugin(
    manifest: SourcePluginManifest(
      id: 'local_source',
      name: 'Local source',
      version: '1.0.0',
      apiVersion: 1,
      entry: 'main.js',
    ),
    directory: 'local',
    customEdited: true,
  ),
  InstalledSourcePlugin(
    manifest: SourcePluginManifest(
      id: 'repository_source_with_long_identifier',
      name: 'Repository source with a long display name 漫画源插件',
      version: '2.0.0',
      apiVersion: 1,
      entry: 'main.js',
    ),
    directory: 'repository',
    repository: _repository,
    enabled: false,
  ),
];

Widget _app(
  SourcePluginGateway gateway, {
  Locale locale = const Locale('en'),
  Brightness brightness = Brightness.light,
  double textScale = 1,
}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.purple,
      brightness: brightness,
    ),
  ),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
  home: SourcePluginsPage(manager: gateway),
);

Future<void> _scrollTo(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    250,
    scrollable: find
        .descendant(
          of: find.byType(ListView).hitTestable(),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pumpAndSettle();
}

void main() {
  late _MockPlugins gateway;

  setUp(() {
    gateway = _MockPlugins();
    when(gateway.initialize).thenAnswer((_) async {});
    when(() => gateway.checkingIndex).thenReturn(false);
    when(() => gateway.indexError).thenReturn(null);
    when(() => gateway.availableUpdates).thenReturn([]);
    when(
      gateway.loadUpdateSource,
    ).thenAnswer((_) async => SoftwareUpdateSource.jsDelivr);
    when(() => gateway.installed).thenReturn(_installed);
    when(() => gateway.repositories).thenReturn([_repository]);
    when(() => gateway.errors).thenReturn({
      'repository_source_with_long_identifier':
          'Source could not initialize. Please check the plugin settings.',
    });
    when(() => gateway.entriesFor(_repository)).thenReturn([
      SourcePluginIndexEntry(
        id: 'new_source_with_long_identifier',
        name: 'A new source with a long display name 新漫画源',
        version: '1.0.0',
        downloadUrl: Uri.parse('https://plugins.example.com/new.js'),
      ),
    ]);
    when(() => gateway.refreshRepository(_repository)).thenAnswer((_) async {});
  });

  for (final scenario in [
    (width: 320.0, scale: 1.0, locale: 'en', brightness: Brightness.light),
    (width: 320.0, scale: 2.0, locale: 'en', brightness: Brightness.dark),
    (width: 390.0, scale: 2.0, locale: 'zh', brightness: Brightness.light),
    (width: 1280.0, scale: 1.0, locale: 'zh', brightness: Brightness.dark),
  ]) {
    testWidgets(
      'plugin management fits ${scenario.width}px, ${scenario.scale}x text, ${scenario.locale}, ${scenario.brightness.name}',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(scenario.width, 900);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        await tester.pumpWidget(
          _app(
            gateway,
            locale: Locale(scenario.locale),
            brightness: scenario.brightness,
            textScale: scenario.scale,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        verifyNever(() => gateway.refreshRepository(_repository));

        await _scrollTo(tester, find.text('Local source'));
        Finder cardFor(String name) => find
            .ancestor(
              of: find.text(name),
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is Material &&
                    widget.shape is RoundedRectangleBorder,
              ),
            )
            .first;
        final localPosition = tester.getTopLeft(cardFor('Local source'));
        await _scrollTo(tester, find.text(_installed.last.manifest.name));
        if (scenario.width >= 800) {
          final repositoryPosition = tester.getTopLeft(
            cardFor(_installed.last.manifest.name),
          );
          expect(repositoryPosition.dy, localPosition.dy);
          expect(repositoryPosition.dx, greaterThan(localPosition.dx));
        }
        final strings = AppLocalizations.of(
          tester.element(find.byType(SourcePluginsPage)),
        )!;
        expect(find.text(strings.pluginsLocallyEdited), findsOneWidget);
        expect(find.text(strings.pluginsDisabled), findsOneWidget);
        expect(find.byType(Switch), findsNWidgets(2));
        final settingsButtons = tester.widgetList<TextButton>(
          find.widgetWithText(TextButton, strings.settingsTitle),
        );
        expect(settingsButtons.first.onPressed, isNotNull);
        expect(settingsButtons.last.onPressed, isNull);
        expect(tester.takeException(), isNull);

        await tester.drag(find.byType(TabBarView), const Offset(-600, 0));
        await tester.pumpAndSettle();
        verifyNever(() => gateway.refreshRepository(_repository));
        expect(find.byType(DropdownButton<SoftwareUpdateSource>), findsNothing);
        await _scrollTo(tester, find.text(strings.pluginsInstall));
        expect(
          find.text('A new source with a long display name 新漫画源'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'empty sections show the fixed catalog without repository management',
    (tester) async {
      when(() => gateway.installed).thenReturn([]);
      when(() => gateway.repositories).thenReturn([]);
      when(() => gateway.entriesFor(_repository)).thenReturn([]);
      await tester.pumpWidget(_app(gateway));
      await tester.pumpAndSettle();
      final strings = AppLocalizations.of(
        tester.element(find.byType(SourcePluginsPage)),
      )!;
      await _scrollTo(tester, find.text(strings.pluginsEmpty));
      expect(find.text(strings.pluginsEmpty), findsOneWidget);
      await tester.drag(find.byType(TabBarView), const Offset(-600, 0));
      await tester.pumpAndSettle();
      await _scrollTo(tester, find.text(strings.pluginsRepositoryEmpty));
      expect(find.byType(Switch), findsNothing);
      expect(find.byType(ExpansionTile), findsNothing);
      expect(find.text(strings.pluginsAddRepository), findsNothing);
      expect(find.text(strings.pluginsRemoveRepository), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('page reuses the startup index and refreshes only on request', (
    tester,
  ) async {
    await tester.pumpWidget(_app(gateway));
    await tester.pumpAndSettle();
    final s = AppLocalizations.of(
      tester.element(find.byType(SourcePluginsPage)),
    )!;
    await tester.tap(find.widgetWithText(Tab, s.pluginsAvailable));
    await tester.pumpAndSettle();
    expect(
      find.text('A new source with a long display name 新漫画源'),
      findsOneWidget,
    );
    verifyNever(gateway.checkStartupUpdates);
    verifyNever(() => gateway.refreshRepository(_repository));
    await tester.tap(find.text(s.pluginsRefresh));
    await tester.pumpAndSettle();
    verify(() => gateway.refreshRepository(_repository)).called(1);
    await tester.drag(find.byType(TabBarView), const Offset(600, 0));
    await tester.pumpAndSettle();
    expect(find.text('Local source'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(_app(gateway));
    await tester.pumpAndSettle();
    verifyNever(() => gateway.refreshRepository(_repository));
    verifyNever(gateway.loadUpdateSource);
    expect(tester.takeException(), isNull);
  });

  testWidgets('startup index failures remain visible without refetching', (
    tester,
  ) async {
    when(() => gateway.indexError).thenReturn('Index unavailable');
    await tester.pumpWidget(_app(gateway));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(TabBarView), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(find.text('Index unavailable'), findsOneWidget);
    verifyNever(() => gateway.refreshRepository(_repository));
    expect(tester.takeException(), isNull);
  });

  testWidgets('repository refresh only shows progress on the available tab', (
    tester,
  ) async {
    final pending = Completer<void>();
    when(
      () => gateway.refreshRepository(_repository),
    ).thenAnswer((_) => pending.future);
    await tester.pumpWidget(_app(gateway));
    await tester.pumpAndSettle();
    final s = AppLocalizations.of(
      tester.element(find.byType(SourcePluginsPage)),
    )!;
    await tester.tap(find.widgetWithText(Tab, s.pluginsAvailable));
    await tester.pumpAndSettle();
    await tester.tap(find.text(s.pluginsRefresh));
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    await tester.tap(find.widgetWithText(Tab, s.pluginsInstalled));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(LinearProgressIndicator), findsNothing);
    await tester.tap(find.widgetWithText(Tab, s.pluginsAvailable));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    pending.complete();
    await tester.pumpAndSettle();
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'update check stays on installed tab and uses the shared prompt',
    (tester) async {
      final pending = Completer<SourcePluginIndexEntry?>();
      when(
        () => gateway.checkUpdate(_installed.last.manifest.id),
      ).thenAnswer((_) => pending.future);
      await tester.pumpWidget(_app(gateway));
      await tester.pumpAndSettle();
      final s = AppLocalizations.of(
        tester.element(find.byType(SourcePluginsPage)),
      )!;
      final checkUpdate = find
          .widgetWithText(TextButton, s.pluginsCheckUpdate)
          .first;
      await _scrollTo(tester, checkUpdate);
      await tester.tap(checkUpdate);
      await tester.pump();
      await tester.drag(
        find.byKey(const PageStorageKey('installed-plugins')),
        const Offset(0, 1000),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        find.descendant(
          of: find.byKey(const PageStorageKey('installed-plugins')),
          matching: find.byType(LinearProgressIndicator),
        ),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(Tab, s.pluginsAvailable));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(LinearProgressIndicator), findsNothing);
      pending.complete(null);
      await tester.pumpAndSettle();
      expect(find.text(s.pluginsNoUpdate), findsOneWidget);
      expect(find.byIcon(Icons.tips_and_updates_rounded), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  for (final enabled in [false, true]) {
    testWidgets('toggling enabled to $enabled preserves the installed layout', (
      tester,
    ) async {
      var installed = [
        _installed.first.copyWith(enabled: !enabled),
        _installed.last,
      ];
      when(() => gateway.installed).thenAnswer((_) => installed);
      final pending = Completer<void>();
      when(() => gateway.setEnabled('local_source', enabled)).thenAnswer((
        _,
      ) async {
        await pending.future;
        installed = [
          installed.first.copyWith(enabled: enabled),
          installed.last,
        ];
      });
      await tester.pumpWidget(_app(gateway));
      await tester.pumpAndSettle();
      final toggle = find.byType(Switch).first;
      await _scrollTo(tester, toggle);
      final element = tester.element(toggle);
      final position = tester.getTopLeft(toggle);
      await tester.tap(toggle);
      await tester.pump();
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(tester.element(toggle), same(element));
      expect(tester.getTopLeft(toggle), position);
      expect(tester.widget<Switch>(toggle).value, enabled);
      expect(tester.widget<Switch>(toggle).onChanged, isNull);
      expect(
        tester.widget<Switch>(find.byType(Switch).last).onChanged,
        isNotNull,
      );
      pending.complete();
      await tester.pumpAndSettle();
      expect(tester.element(toggle), same(element));
      expect(tester.getTopLeft(toggle), position);
      expect(tester.widget<Switch>(toggle).value, enabled);
      expect(tester.widget<Switch>(toggle).onChanged, isNotNull);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('failed toggles restore the switch and show the error', (
    tester,
  ) async {
    final pending = Completer<void>();
    when(
      () => gateway.setEnabled('local_source', false),
    ).thenAnswer((_) => pending.future);
    await tester.pumpWidget(_app(gateway));
    await tester.pumpAndSettle();
    final toggle = find.byType(Switch).first;
    await _scrollTo(tester, toggle);
    await tester.tap(toggle);
    await tester.pump();
    expect(tester.widget<Switch>(toggle).value, isFalse);
    pending.completeError(StateError('Unable to disable plugin'));
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(toggle).value, isTrue);
    expect(tester.widget<Switch>(toggle).onChanged, isNotNull);
    expect(find.textContaining('Unable to disable plugin'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('initialization disables actions and reports failure', (
    tester,
  ) async {
    final pending = Completer<void>();
    when(gateway.initialize).thenAnswer((_) => pending.future);
    await tester.pumpWidget(_app(gateway));
    await tester.pump();
    final strings = AppLocalizations.of(
      tester.element(find.byType(SourcePluginsPage)),
    )!;
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, strings.pluginsImportLocal),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widgetList<Switch>(find.byType(Switch))
          .every((s) => s.onChanged == null),
      isTrue,
    );
    pending.completeError(StateError('Unable to load plugins'));
    await tester.pumpAndSettle();
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.textContaining('Unable to load plugins'), findsOneWidget);
    expect(find.byIcon(Icons.tips_and_updates_rounded), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, strings.pluginsImportLocal),
          )
          .onPressed,
      isNotNull,
    );
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
