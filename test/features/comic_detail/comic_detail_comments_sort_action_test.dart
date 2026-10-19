import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/comic_detail/view/comic_detail_panels.dart';

final _action = find.byKey(const ValueKey('comic-detail-comments-sort'));

Future<TabController> _pumpTabs(
  WidgetTester tester, {
  int initialIndex = 0,
}) async {
  final tabs = TabController(
    length: 3,
    initialIndex: initialIndex,
    vsync: tester,
  );
  addTearDown(tabs.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            ComicDetailCommentsSortAction(tabController: tabs, tabIndex: 1),
            Expanded(
              child: TabBarView(
                controller: tabs,
                children: const [
                  Center(child: Text('Info')),
                  Center(child: Text('Comments')),
                  Center(child: Text('Related')),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return tabs;
}

void main() {
  for (final otherIndex in [0, 2]) {
    testWidgets('entering comments from $otherIndex starts showing halfway', (
      tester,
    ) async {
      final tabs = await _pumpTabs(tester, initialIndex: otherIndex);
      tabs.animateTo(
        1,
        duration: const Duration(seconds: 1),
        curve: Curves.linear,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 490));
      expect(_action, findsNothing);

      await tester.pump(const Duration(milliseconds: 20));
      expect(tabs.indexIsChanging, isTrue);
      expect(_action, findsOneWidget);
      await tester.pump(const Duration(milliseconds: 100));
      final fade = tester.widget<FadeTransition>(
        find.ancestor(of: _action, matching: find.byType(FadeTransition)).first,
      );
      expect(fade.opacity.value, inExclusiveRange(0, 1));
      await tester.pumpAndSettle();
    });

    testWidgets('leaving comments for $otherIndex starts hiding halfway', (
      tester,
    ) async {
      final tabs = await _pumpTabs(tester, initialIndex: 1);
      tabs.animateTo(
        otherIndex,
        duration: const Duration(seconds: 1),
        curve: Curves.linear,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 490));
      final fade = find
          .ancestor(of: _action, matching: find.byType(FadeTransition))
          .first;
      expect(tester.widget<FadeTransition>(fade).opacity.value, 1);

      await tester.pump(const Duration(milliseconds: 20));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tabs.indexIsChanging, isTrue);
      expect(
        tester.widget<FadeTransition>(fade).opacity.value,
        inExclusiveRange(0, 1),
      );
      await tester.pump(const Duration(milliseconds: 150));
      expect(tabs.indexIsChanging, isTrue);
      expect(_action, findsNothing);
      await tester.pumpAndSettle();
    });
  }

  testWidgets('swiping across halfway and reversing updates visibility', (
    tester,
  ) async {
    final tabs = await _pumpTabs(tester);
    final width = tester.getSize(find.byType(TabBarView)).width;
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(TabBarView)),
    );
    await gesture.moveBy(const Offset(-30, 0));
    await tester.pump();
    await gesture.moveBy(Offset(-width * 0.3, 0));
    await tester.pump();
    expect(tabs.animation!.value, lessThan(0.5));
    expect(_action, findsNothing);

    await gesture.moveBy(Offset(-width * 0.3, 0));
    await tester.pump();
    expect(tabs.animation!.value, greaterThan(0.5));
    expect(_action, findsOneWidget);
    await tester.pump(const Duration(milliseconds: 250));

    await gesture.moveBy(Offset(width * 0.3, 0));
    await tester.pump();
    expect(tabs.animation!.value, lessThan(0.5));
    await tester.pump(const Duration(milliseconds: 250));
    expect(_action, findsNothing);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('switching between other tabs never shows comment sorting', (
    tester,
  ) async {
    final tabs = await _pumpTabs(tester);
    tabs.animateTo(
      2,
      duration: const Duration(seconds: 1),
      curve: Curves.linear,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(tabs.animation!.value, closeTo(1, 0.01));
    expect(_action, findsNothing);
    await tester.pumpAndSettle();
    expect(_action, findsNothing);
  });
}
