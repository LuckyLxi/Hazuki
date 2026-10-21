import 'package:hazuki/services/source/models/source_task.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/comic_detail/view/comic_detail_meta.dart';
import 'package:hazuki/features/home/support/home_sidebar_models.dart';
import 'package:hazuki/features/home/view/home_drawer_profile_header.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/services/source/gateways/source_plugin_gateway.dart';
import 'package:hazuki/services/source/interaction/source_ui_scope.dart';
import 'package:hazuki/services/source/models/source_contract_models.dart';
import 'package:hazuki/services/source/plugins/source_plugin_models.dart';
import 'package:hazuki/services/source/runtime/source_runtime_registry.dart';
import 'package:hazuki/shared/source_presentation.dart';
import 'package:hazuki/widgets/source_plugin_interaction.dart';

class _Plugins extends ChangeNotifier implements SourcePluginGateway {
  _Plugins(this.presentation);
  final Map<String, dynamic> presentation;
  bool enabled = true;
  bool removed = false;
  final calls = <(String, String)>[];
  Future<dynamic> Function()? action;

  @override
  InstalledSourcePlugin? pluginFor(String id) => removed
      ? null
      : InstalledSourcePlugin(
          manifest: SourcePluginManifest(
            id: id,
            name: id,
            version: '1',
            apiVersion: 1,
            entry: 'main.js',
            presentation: presentation,
          ),
          directory: id,
          enabled: enabled,
        );

  @override
  Future<dynamic> runAction(
    String id,
    String actionId, {
    SourceTaskOrigin? taskOrigin,
  }) async {
    calls.add((id, actionId));
    return action == null ? null : action!();
  }

  void change({bool remove = false}) {
    enabled = false;
    removed = remove;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _Plugins plugins;
  late SourceRuntimeRegistry registry;
  late Map<String, dynamic> menus;
  late String activeSource;
  const catalog = [
    SourceCatalogEntry(key: 'custom', name: 'Custom', fileName: 'main.js'),
    SourceCatalogEntry(key: 'other', name: 'Other', fileName: 'main.js'),
  ];
  setUp(() {
    menus = {};
    plugins = _Plugins({'menus': menus});
    activeSource = 'custom';
    registry = SourceRuntimeRegistry(
      allowedSources: catalog,
      activeSourceKey: () => activeSource,
      definitionFor: (key) => catalog.firstWhere((e) => e.key == key),
      runtimePresentationFor: (_) => plugins.presentation,
      loadActiveSourcePreference: () async {},
      activateSource: (_) async {},
      ensureInitialized: ({sourceKey}) async {},
      currentAccountForSource: (_) => null,
      isLoggedForSource: (_) => true,
    );
  });
  tearDown(() {
    registry.dispose();
    plugins.dispose();
  });

  Future<void> mount(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      SourcePresentationScope(
        registry: registry,
        sourcePlugins: plugins,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: Center(child: child)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Widget button({FutureOr<void> Function()? invoke, String? sourceKey}) =>
      SourcePluginButtonInteraction(
        id: 'example',
        title: 'Original',
        sourceKey: sourceKey,
        onInvoke: invoke ?? () {},
        builder: (_, activate) =>
            ElevatedButton(onPressed: activate, child: const Text('Open')),
      );

  void actionMenu() {
    menus['plugin.buttons.example'] = [
      {
        'id': 'tools',
        'title': 'Tools',
        'children': [
          {
            'id': 'more',
            'title': 'More',
            'children': [
              {'action': 'refresh', 'title': 'Refresh'},
            ],
          },
        ],
      },
    ];
  }

  Future<void> runMenu(WidgetTester tester) async {
    for (final title in ['Open', 'Tools', 'More', 'Refresh']) {
      await tester.tap(find.text(title));
      await tester.pumpAndSettle();
    }
  }

  for (final empty in [false, true]) {
    testWidgets(
      'missing or empty declarations run the original once ($empty)',
      (tester) async {
        if (empty) menus['plugin.buttons.example'] = [];
        final pending = Completer<void>();
        var calls = 0;
        await mount(
          tester,
          button(
            invoke: () {
              calls++;
              return pending.future;
            },
          ),
        );
        final activate = tester
            .widget<ElevatedButton>(find.byType(ElevatedButton))
            .onPressed!;
        activate();
        activate();
        await tester.pump();
        expect(calls, 1);
        expect(
          tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
          isNull,
        );
        pending.complete();
        await tester.pumpAndSettle();
        expect(find.byType(BackdropFilter), findsNothing);
        expect(
          tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
          isNotNull,
        );
      },
    );
  }

  testWidgets('default can be nested and runs only after the menus disappear', (
    tester,
  ) async {
    menus['plugin.buttons.example'] = [
      {
        'id': 'tools',
        'title': 'Tools',
        'children': [
          {'value': 'default'},
        ],
      },
    ];
    var calls = 0;
    await mount(
      tester,
      button(
        invoke: () {
          expect(find.byType(BackdropFilter), findsNothing);
          calls++;
        },
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(calls, 0);
    await tester.tap(find.text('Tools'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Original'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(plugins.calls, isEmpty);
  });

  testWidgets(
    'action-only menus omit default and execute the pinned plugin once',
    (tester) async {
      actionMenu();
      final pending = Completer<dynamic>();
      SourceUiScope? scope;
      plugins.action = () {
        expect(find.byType(BackdropFilter), findsNothing);
        scope = SourceUiScope.current;
        return pending.future;
      };
      var defaults = 0;
      await mount(tester, button(sourceKey: 'other', invoke: () => defaults++));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Original'), findsNothing);
      for (final title in ['Tools', 'More', 'Refresh']) {
        await tester.tap(find.text(title));
        await tester.pumpAndSettle();
      }
      expect(plugins.calls, [('other', 'refresh')]);
      expect(scope?.available, isTrue);
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull,
      );
      pending.complete();
      await tester.pumpAndSettle();
      expect(defaults, 0);
      expect(tester.takeException(), isNull);
    },
  );

  for (final mobile in [true, false]) {
    testWidgets(
      'copy ID ignores menu declarations and copies through its existing gesture (mobile: $mobile)',
      (tester) async {
        menus['plugin.buttons.copyComicId'] = [
          {
            'id': 'copy',
            'title': 'Copy choices',
            'children': [
              {'value': 'default'},
              {'action': 'bookmark', 'title': 'Bookmark'},
            ],
          },
        ];
        var copies = 0;
        await mount(
          tester,
          ComicDetailIdRow(
            id: '123',
            useMobileStyle: mobile,
            onCopy: () => copies++,
          ),
        );
        if (mobile) {
          await tester.tap(find.text('ID: 123'));
          await tester.pumpAndSettle();
          expect(find.text('Copy choices'), findsNothing);
          await tester.longPress(find.text('ID: 123'));
        } else {
          await tester.tap(find.byIcon(Icons.copy_all_outlined));
        }
        await tester.pumpAndSettle();
        expect(copies, 1);
        expect(find.text('Copy choices'), findsNothing);
        expect(plugins.calls, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('home check-in preserves the async original behind its menu', (
    tester,
  ) async {
    menus['plugin.buttons.checkIn'] = [
      {
        'id': 'checkIn',
        'title': 'Check-in choices',
        'children': [
          {'value': 'default', 'title': 'Run check-in'},
        ],
      },
    ];
    final pending = Completer<void>();
    var calls = 0;
    await mount(
      tester,
      SizedBox(
        width: 304,
        child: HomeDrawerProfileHeader(
          profile: const HomeSidebarProfileState(
            isLogged: true,
            profileLoading: false,
            avatarUrl: '',
            username: 'Reader',
            autoCheckInEnabled: false,
            showCheckInActions: true,
            checkInBusy: false,
            checkedInToday: false,
          ),
          activeSourceKey: 'custom',
          backgroundColor: Colors.white,
          actions: HomeSidebarActions(
            onCheckInPressed: () {
              calls++;
              return pending.future;
            },
          ),
        ),
      ),
    );
    final button = find.byType(FilledButton);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(calls, 0);
    await tester.tap(find.text('Check-in choices'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Run check-in'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    pending.complete();
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });

  for (final change in ['source', 'disable', 'uninstall', 'dispose']) {
    testWidgets('$change closes nested menus without executing', (
      tester,
    ) async {
      actionMenu();
      await mount(tester, button());
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tools'));
      await tester.pumpAndSettle();
      if (change == 'source') {
        activeSource = 'other';
        registry.notifyChanged();
      } else if (change == 'dispose') {
        await mount(tester, const SizedBox());
      } else {
        plugins.change(remove: change == 'uninstall');
      }
      await tester.pumpAndSettle();
      expect(find.byType(BackdropFilter), findsNothing);
      expect(plugins.calls, isEmpty);
      expect(tester.takeException(), isNull);
    });

    for (final declared in [false, true]) {
      testWidgets(
        '$change cancels ${declared ? 'menu action' : 'default operation'} and suppresses late UI',
        (tester) async {
          if (declared) actionMenu();
          final pending = Completer<dynamic>();
          SourceUiScope? scope;
          plugins.action = () {
            scope = SourceUiScope.current;
            return pending.future;
          };
          await mount(
            tester,
            button(
              invoke: () async {
                await plugins.runAction('custom', 'original');
              },
            ),
          );
          if (declared) {
            await runMenu(tester);
          } else {
            await tester.tap(find.text('Open'));
            await tester.pumpAndSettle();
          }
          expect(scope?.available, isTrue);
          if (change == 'source') {
            activeSource = 'other';
            registry.notifyChanged();
          } else if (change == 'dispose') {
            await mount(tester, const SizedBox());
          } else {
            plugins.change(remove: change == 'uninstall');
          }
          await tester.pumpAndSettle();
          expect(scope?.available, isFalse);
          pending.complete('Late result');
          await tester.pumpAndSettle();
          expect(find.text('Late result'), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
