import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/favorite/state/favorite_page_state.dart';
import 'package:hazuki/features/home/view/favorite_app_bar_actions.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/source/gateways/source_plugin_gateway.dart';
import 'package:hazuki/services/source/interaction/source_ui_scope.dart';
import 'package:hazuki/services/source/plugins/source_favorite_menu.dart';
import 'package:hazuki/services/source/plugins/source_plugin_models.dart';
import 'package:hazuki/widgets/hazuki_frosted_menu_button.dart';
import 'package:mocktail/mocktail.dart';

class _Gateway extends Mock implements SourcePluginGateway {}

final _menu = SourceFavoriteMenuEntry.parseList([
  {
    'id': 'saved',
    'title': {'zh': '收藏时间', 'en': 'Saved'},
    'children': [
      {'order': 'dd'},
      {'order': 'da'},
      {
        'action': 'export',
        'title': {'zh': '导出', 'en': 'Export'},
      },
    ],
  },
  {
    'id': 'empty',
    'title': 'Unsupported',
    'children': [
      {'order': 'missing'},
    ],
  },
]);

Future<void> _pumpMenu(
  WidgetTester tester, {
  required _Gateway gateway,
  ValueChanged<String>? onSort,
  FavoritePageMode mode = FavoritePageMode.cloud,
  List<String> orders = const ['dd', 'da', 'score'],
  bool logged = true,
  String sourceKey = 'custom',
  List<SourceFavoriteMenuEntry> localMenu = const [],
}) async {
  final state = FavoritePageData()..mode = mode;
  state.favoriteSortOrder = 'dd';
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Align(
          alignment: Alignment.topRight,
          child: FavoriteAppBarActions(
            state: state.buildAppBarActionsState(
              isLogged: logged,
              supportFavoriteSortOrder: orders.length > 1,
              supportFavoriteFolderAdd: false,
              favoriteSortOrders: orders,
              favoriteSortLabels: const {'score': 'Score'},
              favoriteMenu: _menu,
              localFavoriteMenu: localMenu,
              sourceKey: sourceKey,
            ),
            sourcePlugins: gateway,
            onSortSelected: onSort ?? (_) {},
            onCreateFolderPressed: () {},
            onModeTogglePressed: () {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openSubmenu(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.sort_rounded));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Saved'));
  await tester.pumpAndSettle();
}

void main() {
  late _Gateway gateway;
  setUp(() {
    gateway = _Gateway();
    when(() => gateway.pluginFor('custom')).thenReturn(
      InstalledSourcePlugin(
        manifest: SourcePluginManifest.fromJson({
          'id': 'custom',
          'name': 'Custom',
          'version': '1',
          'entry': 'main.js',
        }),
        directory: 'custom',
      ),
    );
  });

  testWidgets(
    'local favorites accept an explicit generic menu and retain host sorting',
    (tester) async {
      final selected = <String>[];
      await _pumpMenu(
        tester,
        gateway: gateway,
        mode: FavoritePageMode.local,
        onSort: selected.add,
        localMenu: SourceFavoriteMenuEntry.parseList([
          {
            'id': 'saved',
            'title': 'Local saved',
            'children': [
              {'value': 'savedOldest'},
            ],
          },
        ]),
      );
      await tester.tap(find.byIcon(Icons.sort_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Local saved'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Old to new'));
      await tester.pumpAndSettle();
      expect(selected, ['savedOldest']);
      verifyNever(
        () => gateway.runAction(
          any(),
          any(),
          taskOrigin: any(named: 'taskOrigin'),
        ),
      );
    },
  );

  testWidgets(
    'declared sort groups keep order values and append omitted orders',
    (tester) async {
      final selected = <String>[];
      await _pumpMenu(tester, gateway: gateway, onSort: selected.add);
      await tester.tap(find.byIcon(Icons.sort_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Score'), findsOneWidget);
      expect(find.text('Unsupported'), findsNothing);
      expect(find.text('New to old'), findsNothing);
      await tester.tap(find.text('Saved'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      await tester.tap(find.text('Old to new'));
      await tester.pumpAndSettle();
      expect(selected, ['da']);
      verifyNever(
        () => gateway.runAction(
          any(),
          any(),
          taskOrigin: any(named: 'taskOrigin'),
        ),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'action runs once after menus close with a UI scope and busy guard',
    (tester) async {
      final done = Completer<dynamic>();
      SourceUiScope? scope;
      when(
        () => gateway.runAction(
          'custom',
          'export',
          taskOrigin: any(named: 'taskOrigin'),
        ),
      ).thenAnswer((_) {
        expect(find.byType(BackdropFilter), findsNothing);
        scope = SourceUiScope.current;
        return done.future;
      });
      await _pumpMenu(tester, gateway: gateway, orders: const []);
      await _openSubmenu(tester);
      await tester.tap(find.text('Export'));
      await tester.pumpAndSettle();
      expect(scope, isNotNull);
      expect(
        tester.widget<IconButton>(find.byType(IconButton)).onPressed,
        isNull,
      );
      await tester.tap(find.byIcon(Icons.sort_rounded));
      await tester.pumpAndSettle();
      verify(
        () => gateway.runAction(
          'custom',
          'export',
          taskOrigin: any(named: 'taskOrigin'),
        ),
      ).called(1);
      done.complete(null);
      await tester.pumpAndSettle();
      expect(
        tester.widget<IconButton>(find.byType(IconButton)).onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('action errors are shown and restore the button', (tester) async {
    when(
      () => gateway.runAction(
        'custom',
        'export',
        taskOrigin: any(named: 'taskOrigin'),
      ),
    ).thenAnswer((_) async => throw StateError('Export failed'));
    await _pumpMenu(tester, gateway: gateway);
    await _openSubmenu(tester);
    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Export failed'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(
      tester.widget<IconButton>(find.byType(IconButton)).onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('source changes discard the open menu selection', (tester) async {
    await _pumpMenu(tester, gateway: gateway);
    await _openSubmenu(tester);
    await _pumpMenu(tester, gateway: gateway, sourceKey: 'other');
    expect(find.text('Export'), findsNothing);
    verifyNever(
      () =>
          gateway.runAction(any(), any(), taskOrigin: any(named: 'taskOrigin')),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'local favorites keep the original menu and logged out cloud hides it',
    (tester) async {
      await _pumpMenu(tester, gateway: gateway, mode: FavoritePageMode.local);
      expect(find.byType(HazukiFrostedMenuButton<String>), findsOneWidget);
      expect(
        find.byType(HazukiFrostedMenuButton<SourceFavoriteMenuEntry>),
        findsNothing,
      );
      await _pumpMenu(tester, gateway: gateway, logged: false);
      expect(find.byIcon(Icons.sort_rounded), findsNothing);
    },
  );
}
