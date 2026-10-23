import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/widgets/hazuki_frosted_menu.dart';
import 'package:hazuki/widgets/hazuki_frosted_menu_button.dart';

final _surface = find.byKey(const ValueKey('hazuki-frosted-menu-surface'));

Future<Rect> _openMenu(
  WidgetTester tester, {
  Alignment alignment = Alignment.center,
  List<String> labels = const ['a', 'b'],
  ValueChanged<int>? onSelected,
  TextScaler textScaler = TextScaler.noScaling,
  List<HazukiFrostedMenuOption<int>>? options,
  Brightness brightness = Brightness.light,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(brightness: brightness),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      ),
      home: Scaffold(
        body: Align(
          alignment: alignment,
          child: HazukiFrostedMenuButton<int>(
            selected: 0,
            options:
                options ??
                [
                  for (var i = 0; i < labels.length; i++)
                    HazukiFrostedMenuOption(value: i, label: labels[i]),
                ],
            onSelected: onSelected ?? (_) {},
          ),
        ),
      ),
    ),
  );
  final button = find.byType(HazukiFrostedMenuButton<int>);
  final anchor = tester.getRect(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
  return anchor;
}

void main() {
  const nested = <HazukiFrostedMenuOption<int>>[
    HazukiFrostedMenuOption.submenu(
      label: 'Group',
      children: [
        HazukiFrostedMenuOption(value: 0, label: 'First'),
        HazukiFrostedMenuOption.submenu(
          label: 'More',
          children: [HazukiFrostedMenuOption(value: 1, label: 'Last')],
        ),
      ],
    ),
    HazukiFrostedMenuOption(value: 2, label: 'Root option'),
  ];

  for (final brightness in Brightness.values) {
    testWidgets(
      'submenus grow from the tapped row over a dimmed parent and return one leaf value ($brightness)',
      (tester) async {
        final values = <int>[];
        await _openMenu(
          tester,
          options: nested,
          onSelected: values.add,
          brightness: brightness,
        );
        final originalParent = tester.getRect(_surface);
        final row = tester.getRect(find.text('Group'));
        await tester.tap(find.text('Group'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 70));
        final fade = find.byKey(
          const ValueKey('hazuki-frosted-menu-content-fade'),
        );
        expect(tester.widget<Opacity>(fade).opacity, inExclusiveRange(0.5, 1));
        expect(tester.getRect(_surface), originalParent);
        await tester.pumpAndSettle();
        expect(_surface, findsOneWidget);
        // 父菜单不再缩小，只压暗并淡化内容。
        expect(tester.getRect(_surface), originalParent);
        expect(tester.widget<Opacity>(fade).opacity, closeTo(0.5, 0.001));
        final submenu = tester.getRect(
          find.byKey(const ValueKey('hazuki-frosted-menu-submenu-surface')),
        );
        expect(submenu.width, greaterThan(originalParent.width));
        // 右缘与父菜单对齐，只向左下方展开。
        expect(submenu.right, closeTo(originalParent.right, 0.01));
        // 父菜单底色淡出，子菜单的模糊才能采样到页面颜色。
        final fill =
            tester
                    .widget<DecoratedBox>(
                      find.byKey(const ValueKey('hazuki-frosted-menu-fill')),
                    )
                    .decoration
                as BoxDecoration;
        expect(fill.gradient!.colors.first.a, lessThan(0.2));
        // 子菜单标题行落在被点击的那一行上。
        final headers = find.text('Group');
        expect(headers, findsNWidgets(2));
        expect(tester.getRect(headers.last).top, closeTo(row.top, 0.01));
        expect(
          (tester.widget<DecoratedBox>(
            find.byKey(const ValueKey('hazuki-frosted-menu-dim')),
          )).decoration,
          BoxDecoration(color: Colors.black.withValues(alpha: 0.12)),
        );
        expect(find.byIcon(Icons.check_rounded), findsOneWidget);
        expect(
          tester
              .getRect(_surface)
              .overlaps(
                tester.getRect(
                  find.byKey(
                    const ValueKey('hazuki-frosted-menu-submenu-surface'),
                  ),
                ),
              ),
          isTrue,
        );
        final middleSurface = find.byKey(
          const ValueKey('hazuki-frosted-menu-submenu-surface'),
        );
        final originalMiddle = tester.getRect(middleSurface);
        await tester.tap(find.text('More'));
        await tester.pumpAndSettle();
        expect(tester.getRect(middleSurface), originalMiddle);
        expect(tester.getRect(_surface), originalParent);
        for (final prefix in [
          'hazuki-frosted-menu',
          'hazuki-frosted-menu-submenu',
        ]) {
          final dim = tester.widget<DecoratedBox>(
            find.byKey(ValueKey('$prefix-dim')),
          );
          final overlay = (dim.decoration as BoxDecoration).color!;
          // Additional nesting must keep each covered menu only gently dimmed.
          expect(overlay.a, inExclusiveRange(0, 0.15));
        }
        await tester.tap(find.text('Last'));
        await tester.pumpAndSettle();
        expect(values, [1]);
        expect(_surface, findsNothing);
        expect(find.byType(BackdropFilter), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'header, system back and outside tap return to parent without selecting',
    (tester) async {
      final values = <int>[];
      await _openMenu(tester, options: nested, onSelected: values.add);
      final originalParent = tester.getRect(_surface);
      for (final dismiss in ['header', 'back', 'outside']) {
        await tester.tap(find.text('Group'));
        await tester.pumpAndSettle();
        if (dismiss == 'header') {
          await tester.tap(
            find.byKey(const ValueKey('hazuki-frosted-menu-submenu-back')),
          );
        } else if (dismiss == 'back') {
          await tester.binding.handlePopRoute();
        } else {
          await tester.tapAt(const Offset(10, 10));
        }
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 70));
        expect(tester.getRect(_surface), originalParent);
        final closingDim = tester.widget<DecoratedBox>(
          find.byKey(const ValueKey('hazuki-frosted-menu-dim')),
        );
        expect(
          (closingDim.decoration as BoxDecoration).color!.a,
          inExclusiveRange(0, 0.12),
        );
        await tester.pumpAndSettle();
        expect(_surface, findsOneWidget);
        expect(tester.getRect(_surface), originalParent);
        final dim = tester.widget<DecoratedBox>(
          find.byKey(const ValueKey('hazuki-frosted-menu-dim')),
        );
        expect((dim.decoration as BoxDecoration).color!.a, 0);
        expect(
          find.byKey(const ValueKey('hazuki-frosted-menu-submenu-surface')),
          findsNothing,
        );
        expect(values, isEmpty);
      }
      await tester.tap(find.text('Root option'));
      await tester.pumpAndSettle();
      expect(values, [2]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'submenu grows toward the bottom right without room on the left',
    (tester) async {
      await _openMenu(tester, alignment: Alignment.topLeft, options: nested);
      final parent = tester.getRect(_surface);
      await tester.tap(find.text('Group'));
      await tester.pumpAndSettle();
      final submenu = tester.getRect(
        find.byKey(const ValueKey('hazuki-frosted-menu-submenu-surface')),
      );
      expect(submenu.left, closeTo(parent.left, 0.01));
      expect(submenu.right, greaterThan(parent.right));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('submenu fits a narrow screen with large text and scrolls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(280, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    int? selected;
    await _openMenu(
      tester,
      alignment: Alignment.bottomRight,
      textScaler: TextScaler.linear(2),
      onSelected: (value) => selected = value,
      options: [
        HazukiFrostedMenuOption.submenu(
          label: 'Long group title',
          children: [
            for (var i = 0; i < 20; i++)
              HazukiFrostedMenuOption(value: i, label: 'Option $i'),
          ],
        ),
      ],
    );
    await tester.tap(find.text('Long group title'));
    await tester.pumpAndSettle();
    final rect = tester.getRect(
      find.byKey(const ValueKey('hazuki-frosted-menu-submenu-surface')),
    );
    expect(rect.left, greaterThanOrEqualTo(12));
    expect(rect.top, greaterThanOrEqualTo(12));
    expect(rect.right, lessThanOrEqualTo(268));
    expect(rect.bottom, lessThanOrEqualTo(468));
    await tester.scrollUntilVisible(
      find.text('Option 19'),
      150,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('hazuki-frosted-menu-submenu-surface')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(find.text('Option 19'));
    await tester.pumpAndSettle();
    expect(selected, 19);
    expect(tester.takeException(), isNull);
  });

  testWidgets('menu opens over its button and fits short labels', (
    tester,
  ) async {
    final anchor = await _openMenu(tester);
    final menu = tester.getRect(_surface);

    expect(menu.overlaps(anchor), isTrue);
    expect(menu.top, anchor.top);
    expect(menu.right, anchor.right);
    expect(menu.width, lessThan(120));
    expect(find.text('a').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('check stays beside a short label when other labels are longer', (
    tester,
  ) async {
    await _openMenu(tester, labels: ['a', 'A longer option']);

    final text = tester.getRect(find.text('a'));
    final check = tester.getRect(find.byIcon(Icons.check_rounded));
    expect(check.left - text.right, closeTo(8, 0.01));

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(_surface, findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final alignment in [Alignment.topRight, Alignment.bottomLeft]) {
    testWidgets('menu stays on screen at $alignment', (tester) async {
      final anchor = await _openMenu(tester, alignment: alignment);
      final menu = tester.getRect(_surface);

      expect(menu.overlaps(anchor), isTrue);
      expect(menu.left, greaterThanOrEqualTo(12));
      expect(menu.top, greaterThanOrEqualTo(12));
      expect(menu.right, lessThanOrEqualTo(788));
      expect(menu.bottom, lessThanOrEqualTo(588));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('long labels wrap with large text on a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(280, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _openMenu(
      tester,
      labels: ['A long menu option that needs multiple lines', 'b'],
      textScaler: TextScaler.linear(2),
    );

    expect(tester.getSize(_surface).width, lessThanOrEqualTo(240));
    expect(
      tester
          .getSize(find.text('A long menu option that needs multiple lines'))
          .height,
      greaterThan(48),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('long menus scroll and return the selected value', (
    tester,
  ) async {
    int? selected;
    await _openMenu(
      tester,
      alignment: Alignment.bottomRight,
      labels: List.generate(30, (index) => 'Option $index'),
      onSelected: (value) => selected = value,
    );

    await tester.scrollUntilVisible(find.text('Option 29'), 200);
    await tester.tap(find.text('Option 29'));
    await tester.pumpAndSettle();

    expect(selected, 29);
    expect(_surface, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'setting tile shows the value pill and opens from the whole row',
    (tester) async {
      var selected = 'mid';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => HazukiMenuSettingTile<String>(
                leading: const Icon(Icons.high_quality_outlined),
                title: 'Quality',
                subtitle: 'From source',
                selected: selected,
                options: const [
                  HazukiFrostedMenuOption(value: 'low', label: 'Low'),
                  HazukiFrostedMenuOption(value: 'mid', label: 'Medium'),
                  HazukiFrostedMenuOption(value: 'high', label: 'High'),
                ],
                onSelected: (value) => setState(() => selected = value),
              ),
            ),
          ),
        ),
      );
      final tile = find.byType(HazukiMenuSettingTile<String>);
      expect(
        find.descendant(of: tile, matching: find.text('Medium')),
        findsOneWidget,
      );
      // 点标题区域（而非右侧胶囊）也应弹出菜单。
      await tester.tap(find.text('From source'));
      await tester.pumpAndSettle();
      expect(_surface, findsOneWidget);
      await tester.tap(find.text('High'));
      await tester.pumpAndSettle();
      expect(selected, 'high');
      expect(_surface, findsNothing);
      expect(
        find.descendant(of: tile, matching: find.text('High')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
