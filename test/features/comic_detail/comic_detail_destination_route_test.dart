import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hazuki/features/comic_detail/view/comic_detail_destination_route.dart';
import 'package:hazuki/shared/navigation/snapshotting_page_route.dart';
import 'package:hazuki/shared/windows/windows_comic_detail.dart';

void main() {
  for (final destination in ['Reader', 'Tag search']) {
    testWidgets('$destination uses a matching horizontal push and return', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.android),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push<void>(
                  buildSnapshottingPageRoute<void>(
                    allowSnapshotting: false,
                    builder: (context) => Scaffold(
                      body: TextButton(
                        onPressed: () => Navigator.of(context).push<void>(
                          buildComicDetailDestinationRoute(
                            context,
                            (_) => Scaffold(body: Text(destination)),
                          ),
                        ),
                        child: const Text('Detail'),
                      ),
                    ),
                  ),
                ),
                child: const Text('Home'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      final detailRoute = ModalRoute.of(tester.element(find.text('Detail')))!;
      await tester.tap(find.text('Detail'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
      final route = ModalRoute.of(tester.element(find.text(destination)))!;
      expect(route, isA<CupertinoPageRoute<void>>());
      expect(detailRoute.canTransitionTo(route), isTrue);
      expect(route.transitionDuration, const Duration(milliseconds: 500));
      expect(
        route.reverseTransitionDuration,
        const Duration(milliseconds: 500),
      );
      expect(
        _slides(tester, find.text(destination)).any(
          (slide) =>
              slide.position.value.dx > 0.9 && slide.position.value.dy == 0,
        ),
        isTrue,
      );
      await tester.pump(const Duration(milliseconds: 250));
      expect(
        _slides(tester, find.text('Detail')).any(
          (slide) =>
              slide.position.value.dx < 0 && slide.position.value.dy == 0,
        ),
        isTrue,
      );
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.text(destination))).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(
        _slides(tester, find.text(destination)).any(
          (slide) =>
              slide.position.value.dx > 0 && slide.position.value.dy == 0,
        ),
        isTrue,
      );
      await tester.pumpAndSettle();
      expect(find.text('Detail'), findsOneWidget);
      expect(find.text(destination), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Windows destination retains its vertical transition', (
    tester,
  ) async {
    if (!useWindowsComicDetailPanel) return;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.windows),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push<void>(
                buildComicDetailDestinationRoute(
                  context,
                  (_) => const Scaffold(body: Text('Destination')),
                ),
              ),
              child: const Text('Detail'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Detail'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    final route = ModalRoute.of(tester.element(find.text('Destination')))!;
    expect(route, isA<PageRouteBuilder<void>>());
    expect(route.transitionDuration, windowsComicDetailPanelAnimationDuration);
    expect(route.reverseTransitionDuration, const Duration(milliseconds: 280));
    expect(
      _slides(tester, find.text('Destination')).any(
        (slide) =>
            slide.position.value.dy > 0.9 && slide.position.value.dx == 0,
      ),
      isTrue,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.windows]) {
    testWidgets(
      'expanded sheet handoff keeps the return animation ($platform)',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context).push<void>(
                    buildComicDetailDestinationRoute(
                      context,
                      (_) => const Scaffold(body: Text('Reader')),
                      skipEntrance: true,
                    ),
                  ),
                  child: const Text('Detail'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Detail'));
        await tester.pump();
        final reader = find.text('Reader');
        final route = ModalRoute.of(tester.element(reader))!;
        expect(route.animation!.status, AnimationStatus.completed);
        expect(route.animation!.value, 1);
        expect(
          _slides(
            tester,
            reader,
          ).every((slide) => slide.position.value == Offset.zero),
          isTrue,
        );
        Navigator.of(tester.element(reader)).pop();
        await tester.pump();
        await tester.pump(route.reverseTransitionDuration ~/ 2);
        expect(route.animation!.value, inExclusiveRange(0, 1));
        expect(
          _slides(
            tester,
            reader,
          ).any((slide) => slide.position.value != Offset.zero),
          isTrue,
        );
        await tester.pumpAndSettle();
        expect(reader, findsNothing);
        expect(find.text('Detail'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

Iterable<SlideTransition> _slides(WidgetTester tester, Finder child) =>
    tester.widgetList<SlideTransition>(
      find.ancestor(of: child, matching: find.byType(SlideTransition)),
    );
