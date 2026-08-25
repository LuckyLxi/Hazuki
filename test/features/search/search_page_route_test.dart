import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/search/search.dart';

void main() {
  testWidgets('search route keeps both pages live during transitions', (
    tester,
  ) async {
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
    expect(route, isA<PageRoute<void>>());
    expect((route as PageRoute<void>).allowSnapshotting, isFalse);
    expect(route.transitionDuration, const Duration(milliseconds: 280));
    expect(route.reverseTransitionDuration, const Duration(milliseconds: 240));
    expect(_hasSnapshotAncestor(find.text('Home')), isFalse);
    expect(_hasSnapshotAncestor(find.text('Search')), isFalse);
    final slide = tester.widget<SlideTransition>(
      find.ancestor(
        of: find.text('Search'),
        matching: find.byType(SlideTransition),
      ),
    );
    expect(slide.position.value.dx, closeTo(1, 0.02));

    await tester.pump(const Duration(milliseconds: 280));

    expect(_hasSnapshotAncestor(find.text('Search')), isFalse);

    Navigator.of(tester.element(find.text('Search'))).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    expect(_hasSnapshotAncestor(find.text('Home')), isFalse);
    expect(_hasSnapshotAncestor(find.text('Search')), isFalse);

    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
  });
}

bool _hasSnapshotAncestor(Finder finder) {
  return find
      .ancestor(of: finder, matching: find.byType(SnapshotWidget))
      .evaluate()
      .isNotEmpty;
}
