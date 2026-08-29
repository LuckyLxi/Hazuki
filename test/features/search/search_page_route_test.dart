import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/search/search.dart';

void main() {
  testWidgets('search route snapshots only the entering page', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () {
                  Navigator.of(context).push<void>(
                    buildSearchEntryPageRoute<void>(
                      builder: (_) => const Scaffold(body: Text('Search')),
                    ),
                  );
                },
                child: const Text('Home'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Home'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    final route = ModalRoute.of(tester.element(find.text('Search')))!;
    expect(route, isA<CupertinoPageRoute<void>>());
    expect((route as PageRoute<void>).allowSnapshotting, isTrue);
    expect(route.transitionDuration, const Duration(milliseconds: 500));
    expect(route.reverseTransitionDuration, const Duration(milliseconds: 500));
    expect(_isSnapshotting(find.text('Home')), isFalse);
    expect(_isSnapshotting(find.text('Search')), isTrue);
    final searchSlides = tester.widgetList<SlideTransition>(
      find.ancestor(
        of: find.text('Search'),
        matching: find.byType(SlideTransition),
      ),
    );
    expect(searchSlides.any((slide) => slide.position.value.dx > 0.9), isTrue);

    await tester.pump(const Duration(milliseconds: 250));

    final homeSlides = tester.widgetList<SlideTransition>(
      find.ancestor(
        of: find.text('Home'),
        matching: find.byType(SlideTransition),
      ),
    );
    expect(homeSlides.any((slide) => slide.position.value.dx < 0), isTrue);

    await tester.pump(const Duration(milliseconds: 250));

    expect(_isSnapshotting(find.text('Search')), isFalse);

    Navigator.of(tester.element(find.text('Search'))).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    expect(_isSnapshotting(find.text('Home')), isFalse);
    expect(_isSnapshotting(find.text('Search')), isTrue);

    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
  });
}

bool _isSnapshotting(Finder finder) {
  return find
      .ancestor(of: finder, matching: find.byType(SnapshotWidget))
      .evaluate()
      .map((element) => element.widget as SnapshotWidget)
      .any((widget) => widget.controller.allowSnapshotting);
}
