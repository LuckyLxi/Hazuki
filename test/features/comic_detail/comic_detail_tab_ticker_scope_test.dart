import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hazuki/features/comic_detail/view/comic_detail_view_primitives.dart';

void main() {
  testWidgets('active tab does not rebuild when its transition settles', (
    tester,
  ) async {
    late TabController controller;
    var buildCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: DefaultTabController(
          length: 2,
          child: Builder(
            builder: (context) {
              controller = DefaultTabController.of(context);
              return ComicDetailTabTickerScope(
                tabController: controller,
                tabIndex: 1,
                builder: (context, shouldRender) {
                  buildCount++;
                  return const SizedBox.expand(
                    key: ValueKey<String>('target-tab-content'),
                  );
                },
              );
            },
          ),
        ),
      ),
    );

    controller.animateTo(1, duration: const Duration(milliseconds: 300));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(controller.indexIsChanging, isTrue);
    final countAfterActivation = buildCount;

    await tester.pumpAndSettle();

    expect(controller.indexIsChanging, isFalse);
    expect(buildCount, countAfterActivation);
  });

  testWidgets('outgoing tab stops rendering when its ticker is disabled', (
    tester,
  ) async {
    late TabController controller;
    var buildCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: DefaultTabController(
          length: 2,
          child: Builder(
            builder: (context) {
              controller = DefaultTabController.of(context);
              return ComicDetailTabTickerScope(
                tabController: controller,
                tabIndex: 0,
                builder: (context, shouldRender) {
                  buildCount++;
                  return SizedBox.expand(
                    key: ValueKey<String>(
                      shouldRender ? 'retained-tab-content' : 'inactive-tab',
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('retained-tab-content')),
      findsOneWidget,
    );
    final initialBuildCount = buildCount;

    controller.animateTo(1, duration: const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('retained-tab-content')),
      findsNothing,
    );
    final inactiveContent = find.byKey(const ValueKey<String>('inactive-tab'));
    expect(inactiveContent, findsOneWidget);
    expect(buildCount, greaterThan(initialBuildCount));
    final tickerMode = find.ancestor(
      of: inactiveContent,
      matching: find.byType(TickerMode),
    );
    expect(tester.widget<TickerMode>(tickerMode.first).enabled, isFalse);
  });

  testWidgets('hidden tabs detach their scrollables and restore their offset', (
    tester,
  ) async {
    late TabController controller;
    final nestedKey = GlobalKey<NestedScrollViewState>();
    final tabKeys = List.generate(2, (_) => GlobalKey<_KeptScrollTabState>());
    await tester.pumpWidget(
      MaterialApp(
        home: DefaultTabController(
          length: 2,
          child: Builder(
            builder: (context) {
              controller = DefaultTabController.of(context);
              return Scaffold(
                body: NestedScrollView(
                  key: nestedKey,
                  headerSliverBuilder: (context, innerBoxIsScrolled) => [],
                  body: TabBarView(
                    controller: controller,
                    children: List.generate(
                      2,
                      (index) => ComicDetailTabTickerScope(
                        tabController: controller,
                        tabIndex: index,
                        builder: (context, shouldRender) => _KeptScrollTab(
                          key: tabKeys[index],
                          index: index,
                          active: shouldRender,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    final innerController = nestedKey.currentState!.innerController;
    innerController.jumpTo(240);
    await tester.pumpAndSettle();
    final firstOffset = innerController.position.pixels;
    final firstState = tabKeys[0].currentState;

    controller.animateTo(1);
    await tester.pumpAndSettle();
    expect(innerController.positions, hasLength(1));
    await tester.drag(
      find.byKey(const PageStorageKey<String>('scroll-tab-1')),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    expect(innerController.position.pixels, greaterThan(0));
    final secondOffset = innerController.position.pixels;

    controller.animateTo(0);
    await tester.pumpAndSettle();
    expect(innerController.positions, hasLength(1));
    expect(innerController.position.pixels, firstOffset);
    expect(tabKeys[0].currentState, same(firstState));

    controller.animateTo(1);
    await tester.pumpAndSettle();
    expect(innerController.positions, hasLength(1));
    expect(innerController.position.pixels, secondOffset);
  });
}

class _KeptScrollTab extends StatefulWidget {
  const _KeptScrollTab({super.key, required this.index, required this.active});

  final int index;
  final bool active;

  @override
  State<_KeptScrollTab> createState() => _KeptScrollTabState();
}

class _KeptScrollTabState extends State<_KeptScrollTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (!widget.active) return const SizedBox.expand();
    return ListView.builder(
      key: PageStorageKey<String>('scroll-tab-${widget.index}'),
      itemExtent: 60,
      itemCount: 100,
      itemBuilder: (context, index) => Text('Item $index'),
    );
  }
}
