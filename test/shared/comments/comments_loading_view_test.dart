import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/features/comic_detail/view/comic_detail_view_primitives.dart';
import 'package:hazuki/shared/comments/comments_loading_view.dart';
import 'package:hazuki/widgets/hazuki_m3e_loading_indicator.dart';
import 'package:hazuki/widgets/sticker_loading_indicator.dart';

void main() {
  testWidgets('pending details keep one loader throughout tab switching', (
    tester,
  ) async {
    late TabController controller;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DefaultTabController(
          length: 2,
          child: Builder(
            builder: (context) {
              controller = DefaultTabController.of(context);
              return Scaffold(
                body: TabBarView(
                  controller: controller,
                  children: [
                    const SizedBox.expand(),
                    ComicDetailTabTickerScope(
                      tabController: controller,
                      tabIndex: 1,
                      builder: (context, shouldRender) =>
                          const CommentsInitialLoadingView(),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
    controller.animateTo(1, duration: const Duration(milliseconds: 300));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    final loader = find.byType(HazukiM3ELoadingIndicator);
    expect(loader, findsOneWidget);
    final loadingState = tester.state(loader);
    final painterFinder = find.descendant(
      of: loader,
      matching: find.byType(CustomPaint),
    );
    final painter = tester.widget<CustomPaint>(painterFinder).painter;

    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();
    expect(controller.indexIsChanging, isFalse);
    expect(loader, findsOneWidget);
    expect(tester.state(loader), same(loadingState));
    expect(tester.widget<CustomPaint>(painterFinder).painter, same(painter));
    expect(find.byType(HazukiSandyLoadingIndicator), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('comments initial loading uses the M3E indicator', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: CommentsInitialLoadingView()),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('comments-initial-loading')),
      findsOneWidget,
    );
    expect(find.byType(HazukiM3ELoadingIndicator), findsOneWidget);
    expect(find.byType(HazukiSandyLoadingIndicator), findsNothing);

    final customPaintFinder = find.descendant(
      of: find.byType(HazukiM3ELoadingIndicator),
      matching: find.byType(CustomPaint),
    );
    final initialPainter = tester
        .widget<CustomPaint>(customPaintFinder)
        .painter;

    await tester.pump(const Duration(milliseconds: 100));

    expect(
      tester.widget<CustomPaint>(customPaintFinder).painter,
      same(initialPainter),
    );
  });
}
