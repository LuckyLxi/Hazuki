import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/home/view/favorite_app_bar_actions.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/shared/favorites/favorite_app_bar_actions_state.dart';
import 'package:hazuki/widgets/hazuki_frosted_menu_button.dart';

void main() {
  for (final mode in FavoritePageMode.values) {
    testWidgets('$mode sort menu preserves its choices and callbacks', (
      tester,
    ) async {
      final orders = mode == FavoritePageMode.local
          ? ['savedNewest', 'savedOldest', 'readNewest']
          : ['dd', 'da'];
      // 本地模式收藏时间正倒序收进子菜单，顶层只保留其余策略。
      final topLevelValues = mode == FavoritePageMode.local
          ? [null, 'readNewest']
          : orders;
      var selected = orders.first;
      var sortCalls = 0;
      var folderCalls = 0;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: StatefulBuilder(
            builder: (context, setState) => Scaffold(
              appBar: AppBar(
                actions: [
                  FavoriteAppBarActions(
                    state: FavoriteAppBarActionsState(
                      showSort: true,
                      showCreateFolder: true,
                      currentSortOrder: selected,
                      sortOrders: orders,
                      showModeToggle: false,
                      currentMode: mode,
                    ),
                    onSortSelected: (order) {
                      sortCalls++;
                      setState(() => selected = order);
                    },
                    onCreateFolderPressed: () => folderCalls++,
                    onModeTogglePressed: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final button = find.byType(HazukiFrostedMenuButton<String>);
      expect(
        tester
            .widget<HazukiFrostedMenuButton<String>>(button)
            .options
            .map((option) => option.value),
        topLevelValues,
      );
      await tester.tap(find.byIcon(Icons.sort_rounded));
      await tester.pumpAndSettle();
      // 排序按钮形变成毛玻璃菜单，模糊由形变外框在绘制层完成。
      final surface = find.byKey(const ValueKey('hazuki-frosted-menu-surface'));
      expect(surface, findsOneWidget);
      expect(
        tester
            .getRect(surface)
            .contains(tester.getCenter(find.byIcon(Icons.sort_rounded))),
        isTrue,
      );
      await tester.tap(
        find.byKey(ValueKey(('hazuki-frosted-menu', orders.last))),
      );
      await tester.pumpAndSettle();
      expect(selected, orders.last);
      expect(sortCalls, 1);
      expect(
        tester.widget<HazukiFrostedMenuButton<String>>(button).selected,
        orders.last,
      );
      await tester.tap(find.byIcon(Icons.create_new_folder_outlined));
      expect(folderCalls, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('local favorite-time submenu selects saved orders', (
    tester,
  ) async {
    var selected = 'readNewest';
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            appBar: AppBar(
              actions: [
                FavoriteAppBarActions(
                  state: FavoriteAppBarActionsState(
                    showSort: true,
                    showCreateFolder: false,
                    currentSortOrder: selected,
                    sortOrders: const [
                      'savedNewest',
                      'savedOldest',
                      'readNewest',
                    ],
                    showModeToggle: false,
                    currentMode: FavoritePageMode.local,
                  ),
                  onSortSelected: (order) => setState(() => selected = order),
                  onCreateFolderPressed: () {},
                  onModeTogglePressed: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final submenu = tester
        .widget<HazukiFrostedMenuButton<String>>(
          find.byType(HazukiFrostedMenuButton<String>),
        )
        .options
        .first;
    expect(submenu.label, 'Favorite time');
    expect(submenu.children.map((option) => option.label), [
      'New to old',
      'Old to new',
    ]);

    await tester.tap(find.byIcon(Icons.sort_rounded));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey(('hazuki-frosted-menu', 'Favorite time'))),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Old to new'));
    await tester.pumpAndSettle();
    expect(selected, 'savedOldest');
    expect(tester.takeException(), isNull);
  });

  for (final locale in ['zh', 'en']) {
    testWidgets('cloud sort labels follow plugin declarations in $locale', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(locale),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: FavoriteAppBarActions(
              state: const FavoriteAppBarActionsState(
                showSort: true,
                showCreateFolder: false,
                currentSortOrder: 'score',
                sortOrders: ['score', 'mr', 'custom'],
                sortLabels: {
                  'score': {'zh': '评分', 'en': 'Score'},
                  'mr': 'Plugin label',
                },
                showModeToggle: false,
                currentMode: FavoritePageMode.cloud,
              ),
              onSortSelected: (_) {},
              onCreateFolderPressed: () {},
              onModeTogglePressed: () {},
            ),
          ),
        ),
      );
      final menu = tester.widget<HazukiFrostedMenuButton<String>>(
        find.byType(HazukiFrostedMenuButton<String>),
      );
      expect(menu.options.map((option) => option.label), [
        locale == 'zh' ? '评分' : 'Score',
        'Plugin label',
        'custom',
      ]);
    });
  }
}
