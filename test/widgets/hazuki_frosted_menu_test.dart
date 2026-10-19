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
            options: [
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
