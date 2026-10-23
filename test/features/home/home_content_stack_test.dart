import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hazuki/features/home/view/home_content_stack.dart';

void main() {
  testWidgets('slide-fade mode reports the transition without a panel cut', (
    tester,
  ) async {
    final reports = <bool>[];
    Widget build(int index) => MaterialApp(
      home: HomeContentStack(
        currentIndex: index,
        cutTransition: false,
        onTransitionChanged: reports.add,
        discoverChild: const SizedBox.expand(),
        favoriteChild: const SizedBox.expand(),
      ),
    );

    await tester.pumpWidget(build(0));
    expect(find.byType(AnimatedSlide), findsNWidgets(2));

    await tester.pumpWidget(build(1));
    expect(reports, [true]);

    await tester.pump(const Duration(milliseconds: 120));
    expect(reports, [true]);
    await tester.pumpAndSettle();
    expect(reports, [true, false]);
  });
}
