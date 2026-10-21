import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/search/view/search_results_page_widgets.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/services/source/plugins/source_sort_options.dart';
import 'package:hazuki/shared/comments/comments_sort_delegate.dart';
import 'package:hazuki/shared/comments/comments_sort_scope.dart';
import 'package:hazuki/shared/preferences/software_update_source.dart';
import 'package:hazuki/services/source/gateways/source_plugin_gateway.dart';
import 'package:hazuki/services/source/interaction/source_ui_scope.dart';
import 'package:hazuki/services/source/models/source_contract_models.dart';
import 'package:hazuki/services/source/plugins/source_plugin_models.dart';
import 'package:hazuki/services/source/runtime/source_runtime_registry.dart';
import 'package:hazuki/shared/source_presentation.dart';
import 'package:hazuki/widgets/hazuki_frosted_menu.dart';
import 'package:hazuki/widgets/hazuki_frosted_menu_button.dart';
import 'package:mocktail/mocktail.dart';

class _Plugins extends Mock implements SourcePluginGateway {}

class _CommentSort extends ChangeNotifier implements CommentsSortDelegate {
  @override
  String get sourceKey => 'other';
  @override
  SourceCommentSortOptions get sortOptions => const SourceCommentSortOptions(
    orders: {'recent': 'Recent', 'popular': 'Popular'},
  );
  @override
  String selectedOrder = 'recent';
  @override
  Future<void> setOrder(String order) async {
    selectedOrder = order;
    notifyListeners();
  }
}

void main() {
  late _Plugins plugins;
  late SourceRuntimeRegistry registry;
  late Map<String, dynamic> presentation;
  late String activeSource;
  const catalog = [
    SourceCatalogEntry(key: 'custom', name: 'Custom', fileName: 'main.js'),
    SourceCatalogEntry(key: 'other', name: 'Other', fileName: 'main.js'),
  ];
  setUp(() {
    plugins = _Plugins();
    activeSource = 'custom';
    presentation = {
      'menus': <String, dynamic>{
        'my.custom.menu': [
          {
            'id': 'group',
            'title': {'en': 'Choices', 'zh': '选项'},
            'children': [
              {'value': '10'},
              {'value': '20'},
              {'value': 'unsupported'},
            ],
          },
        ],
        'another.menu': [
          {'action': 'refresh', 'title': 'Refresh'},
        ],
      },
    };
    for (final id in ['custom', 'other']) {
      when(() => plugins.pluginFor(id)).thenReturn(
        InstalledSourcePlugin(
          manifest: SourcePluginManifest.fromJson({
            'id': id,
            'name': id,
            'version': '1',
            'entry': 'main.js',
          }),
          directory: id,
        ),
      );
    }
    registry = SourceRuntimeRegistry(
      allowedSources: catalog,
      activeSourceKey: () => activeSource,
      definitionFor: (key) => catalog.firstWhere((e) => e.key == key),
      runtimePresentationFor: (_) => presentation,
      loadActiveSourcePreference: () async {},
      activateSource: (_) async {},
      ensureInitialized: ({sourceKey}) async {},
      currentAccountForSource: (_) => null,
      isLoggedForSource: (_) => true,
    );
  });
  tearDown(() => registry.dispose());

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

  const options = [
    HazukiFrostedMenuOption(value: 10, label: 'Ten'),
    HazukiFrostedMenuOption(value: 20, label: 'Twenty'),
    HazukiFrostedMenuOption(value: 30, label: 'Thirty'),
  ];

  testWidgets('search page sorting consumes the generic search menu', (
    tester,
  ) async {
    (presentation['menus'] as Map)['search.sort'] = [
      {
        'id': 'group',
        'title': 'Search ordering',
        'children': [
          {'value': 'latest'},
          {'value': 'score'},
        ],
      },
    ];
    String? selected;
    await mount(
      tester,
      SizedBox(
        height: 56,
        child: SearchResultsAppBar(
          title: const Text('Results'),
          orderLabels: const {'latest': 'Latest', 'score': 'Score'},
          currentOrderLabel: 'Latest',
          searchOrder: 'latest',
          onOrderMenuOpened: () {},
          onOrderSelected: (value) => selected = value,
        ),
      ),
    );
    await tester.tap(find.byIcon(Icons.swap_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Search ordering'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Score'));
    await tester.pumpAndSettle();
    expect(selected, 'score');
    expect(tester.takeException(), isNull);
  });

  testWidgets('comments page sorting consumes its own generic menu', (
    tester,
  ) async {
    (presentation['menus'] as Map)['comments.sort'] = [
      {
        'id': 'group',
        'title': 'Comment ordering',
        'children': [
          {'value': 'popular'},
        ],
      },
    ];
    final delegate = _CommentSort();
    final binding = CommentsSortBinding()..attach(delegate);
    addTearDown(delegate.dispose);
    addTearDown(binding.dispose);
    await mount(
      tester,
      CommentsSortScope(binding: binding, child: const CommentsSortButton()),
    );
    await tester.tap(find.byIcon(Icons.swap_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Comment ordering'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Popular'));
    await tester.pumpAndSettle();
    expect(delegate.selectedOrder, 'popular');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'valueId preserves enum values instead of returning declaration strings',
    (tester) async {
      (presentation['menus'] as Map)['enum.menu'] = [
        {
          'id': 'group',
          'title': 'Provider',
          'children': [
            {'value': 'github'},
          ],
        },
      ];
      SoftwareUpdateSource? selected;
      await mount(
        tester,
        HazukiFrostedDropdown<SoftwareUpdateSource>(
          selected: SoftwareUpdateSource.jsDelivr,
          options: const [
            HazukiFrostedMenuOption(
              value: SoftwareUpdateSource.jsDelivr,
              label: 'jsDelivr',
            ),
            HazukiFrostedMenuOption(
              value: SoftwareUpdateSource.github,
              label: 'GitHub',
            ),
          ],
          pluginMenu: SourcePluginMenuBinding(
            menuId: 'enum.menu',
            valueId: (value) => value.name,
          ),
          onSelected: (value) => selected = value,
        ),
      );
      await tester.tap(find.text('jsDelivr'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Provider'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('GitHub'));
      await tester.pumpAndSettle();
      expect(selected, SoftwareUpdateSource.github);
    },
  );

  testWidgets(
    'an arbitrary menu ID groups host values and preserves omitted values',
    (tester) async {
      int? selected;
      await mount(
        tester,
        HazukiFrostedMenuButton<int>(
          options: options,
          selected: 10,
          onSelected: (v) => selected = v,
          pluginMenu: const SourcePluginMenuBinding(menuId: 'my.custom.menu'),
        ),
      );
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();
      expect(find.text('Choices'), findsOneWidget);
      expect(find.text('Refresh'), findsNothing);
      expect(find.text('Thirty'), findsOneWidget);
      await tester.tap(find.text('Choices'));
      await tester.pumpAndSettle();
      expect(find.text('unsupported'), findsNothing);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      await tester.tap(find.text('Twenty'));
      await tester.pumpAndSettle();
      expect(selected, 20);
      expect(tester.takeException(), isNull);
    },
  );

  for (final variant in ['dropdown', 'direct']) {
    testWidgets(
      '$variant uses the same declarations and returns the original typed value',
      (tester) async {
        int? selected;
        const binding = SourcePluginMenuBinding<int>(menuId: 'my.custom.menu');
        final anchor = GlobalKey();
        await mount(
          tester,
          variant == 'dropdown'
              ? HazukiFrostedDropdown<int>(
                  options: options,
                  selected: 10,
                  pluginMenu: binding,
                  onSelected: (v) => selected = v,
                )
              : Builder(
                  builder: (context) => TextButton(
                    key: anchor,
                    onPressed: () async {
                      selected = await showHazukiFrostedMenu<int>(
                        context: context,
                        anchorKey: anchor,
                        options: options,
                        selected: 10,
                        pluginMenu: binding,
                      );
                    },
                    child: const Text('Open'),
                  ),
                ),
        );
        await tester.tap(find.text(variant == 'dropdown' ? 'Ten' : 'Open'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Choices'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Twenty'));
        await tester.pumpAndSettle();
        expect(selected, 20);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final declared in [false, true]) {
    testWidgets(
      'missing and empty declarations preserve the flat menu ($declared)',
      (tester) async {
        if (declared) (presentation['menus'] as Map)['no.menu'] = [];
        await mount(
          tester,
          HazukiFrostedMenuButton<int>(
            options: options,
            onSelected: (_) {},
            pluginMenu: const SourcePluginMenuBinding(menuId: 'no.menu'),
          ),
        );
        await tester.tap(find.byType(IconButton));
        await tester.pumpAndSettle();
        expect(find.text('Ten'), findsOneWidget);
        expect(find.text('Twenty'), findsOneWidget);
        expect(find.text('Choices'), findsNothing);
        expect(find.byIcon(Icons.expand_more_rounded), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'menu actions use the declared content source instead of the active source',
    (tester) async {
      when(
        () => plugins.runAction('other', 'refresh'),
      ).thenAnswer((_) async => null);
      await mount(
        tester,
        HazukiFrostedMenuButton<int>(
          options: const [],
          onSelected: (_) => fail('action selected a host value'),
          pluginMenu: const SourcePluginMenuBinding(
            menuId: 'another.menu',
            sourceKey: 'other',
          ),
        ),
      );
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Refresh'));
      await tester.pumpAndSettle();
      verify(() => plugins.runAction('other', 'refresh')).called(1);
      verifyNever(() => plugins.runAction('custom', any()));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('active source changes close an unpinned open menu', (
    tester,
  ) async {
    await mount(
      tester,
      HazukiFrostedMenuButton<int>(
        options: options,
        onSelected: (_) {},
        pluginMenu: const SourcePluginMenuBinding(menuId: 'my.custom.menu'),
      ),
    );
    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choices'));
    await tester.pumpAndSettle();
    activeSource = 'other';
    registry.replaceCatalog(catalog);
    await tester.pumpAndSettle();
    expect(find.text('Choices'), findsNothing);
    expect(find.byType(BackdropFilter), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('changing source cancels a running action interaction', (
    tester,
  ) async {
    final result = Completer<dynamic>();
    SourceUiScope? scope;
    when(() => plugins.runAction('custom', 'refresh')).thenAnswer((_) {
      scope = SourceUiScope.current;
      return result.future;
    });
    await mount(
      tester,
      HazukiFrostedMenuButton<int>(
        options: const [],
        onSelected: (_) {},
        pluginMenu: const SourcePluginMenuBinding(menuId: 'another.menu'),
      ),
    );
    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Refresh'));
    await tester.pumpAndSettle();
    expect(scope?.available, isTrue);
    activeSource = 'other';
    registry.replaceCatalog(catalog);
    await tester.pumpAndSettle();
    expect(scope?.available, isFalse);
    result.complete('Stale result');
    await tester.pumpAndSettle();
    expect(find.text('Stale result'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final disabled in [true, false]) {
    testWidgets(
      'disabled or uninstalled plugins cannot replace a menu ($disabled)',
      (tester) async {
        final installed = plugins.pluginFor('custom')!;
        when(
          () => plugins.pluginFor('custom'),
        ).thenReturn(disabled ? installed.copyWith(enabled: false) : null);
        await mount(
          tester,
          HazukiFrostedMenuButton<int>(
            options: options,
            onSelected: (_) {},
            pluginMenu: const SourcePluginMenuBinding(menuId: 'my.custom.menu'),
          ),
        );
        await tester.tap(find.byType(IconButton));
        await tester.pumpAndSettle();
        expect(find.text('Ten'), findsOneWidget);
        expect(find.text('Choices'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'project code can use native nested dropdown options with a selected label',
    (tester) async {
      int? selected;
      await mount(
        tester,
        HazukiFrostedDropdown<int>(
          selected: 20,
          options: const [
            HazukiFrostedMenuOption.submenu(
              label: 'Native group',
              children: options,
            ),
          ],
          onSelected: (value) => selected = value,
        ),
      );
      expect(find.text('Twenty'), findsOneWidget);
      await tester.tap(find.text('Twenty'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Native group'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ten'));
      await tester.pumpAndSettle();
      expect(selected, 10);
      expect(tester.takeException(), isNull);
    },
  );
}
