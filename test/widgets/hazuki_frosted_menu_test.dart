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
}) async {
  await tester.pumpWidget(
    MaterialApp(
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

  testWidgets(
    'submenus animate over a shrinking dimmed parent and return one leaf value',
    (tester) async {
      final values = <int>[];
      await _openMenu(tester, options: nested, onSelected: values.add);
      final originalParent = tester.getRect(_surface);
      await tester.tap(find.text('Group'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 70));
      final opacity = find.byKey(
        const ValueKey('hazuki-frosted-menu-submenu-opacity'),
      );
      expect(tester.widget<Opacity>(opacity).opacity, inExclusiveRange(0, 1));
      expect(
        tester.getRect(_surface).width,
        inExclusiveRange(originalParent.width * 0.96, originalParent.width),
      );
      await tester.pumpAndSettle();
      expect(_surface, findsOneWidget);
      expect(
        tester.getRect(_surface).width,
        closeTo(originalParent.width * 0.96, 0.01),
      );
      expect(
        tester.getRect(_surface).height,
        closeTo(originalParent.height * 0.96, 0.01),
      );
      expect(
        tester.getRect(_surface).center.dx,
        closeTo(originalParent.center.dx, 0.01),
      );
      expect(
        tester.getRect(_surface).center.dy,
        closeTo(originalParent.center.dy, 0.01),
      );
      expect(
        (tester.widget<DecoratedBox>(
          find.byKey(const ValueKey('hazuki-frosted-menu-dim')),
        )).decoration,
        BoxDecoration(color: Colors.black.withValues(alpha: 0.45)),
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
      expect(
        tester.getRect(middleSurface).width,
        closeTo(originalMiddle.width * 0.96, 0.01),
      );
      expect(
        tester.getRect(_surface).width,
        closeTo(originalParent.width * 0.96, 0.01),
      );
      await tester.tap(find.text('Last'));
      await tester.pumpAndSettle();
      expect(values, [1]);
      expect(_surface, findsNothing);
      expect(find.byType(BackdropFilter), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

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
        expect(
          tester.getRect(_surface).width,
          inExclusiveRange(originalParent.width * 0.96, originalParent.width),
        );
        await tester.pumpAndSettle();
        expect(_surface, findsOneWidget);
        expect(tester.getRect(_surface), originalParent);
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
}
