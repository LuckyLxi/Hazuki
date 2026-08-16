import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/reader/state/reader_runtime_state.dart';
import 'package:hazuki/features/reader/view/reader_bottom_controls.dart';
import 'package:hazuki/features/reader/view/reader_overlay_builders.dart';
import 'package:hazuki/l10n/app_localizations.dart';

void main() {
  testWidgets('offline controls keep local navigation without online actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReaderBottomControls(
            controlsVisible: true,
            readerTheme: ThemeData.dark(),
            pageIndexNotifier: ValueNotifier<int>(0),
            sliderDragging: false,
            sliderDragValue: 0,
            imageCount: 1,
            chapterPanelLoading: false,
            onSliderChangeStart: null,
            onSliderPointerDown: null,
            onSliderChanged: null,
            onSliderChangeEnd: null,
            onOpenChaptersPanel: () {},
            onPreviousChapter: () {},
            onNextChapter: () {},
            onResetZoom: () {},
            isZoomed: false,
            previousTooltip: 'Previous',
            chaptersTooltip: 'Chapters',
            favoriteTooltip: 'Favorite',
            commentsTooltip: 'Comments',
            nextTooltip: 'Next',
            resetZoomLabel: 'Reset',
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.menu_book_rounded), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border_rounded), findsNothing);
    expect(find.byIcon(Icons.mode_comment_outlined), findsNothing);
    expect(find.byIcon(Icons.skip_previous_rounded), findsOneWidget);
    expect(find.byIcon(Icons.skip_next_rounded), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);
  });

  testWidgets('reader progress slider remains continuous while dragging', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReaderBottomControls(
            controlsVisible: true,
            readerTheme: ThemeData.dark(),
            pageIndexNotifier: ValueNotifier<int>(0),
            sliderDragging: false,
            sliderDragValue: 0,
            imageCount: 24,
            chapterPanelLoading: false,
            onSliderChangeStart: (_) {},
            onSliderPointerDown: (_) {},
            onSliderChanged: (_) {},
            onSliderChangeEnd: (_) {},
            onOpenChaptersPanel: () {},
            onPreviousChapter: () {},
            onNextChapter: () {},
            onResetZoom: () {},
            isZoomed: false,
            previousTooltip: 'Previous',
            chaptersTooltip: 'Chapters',
            favoriteTooltip: 'Favorite',
            commentsTooltip: 'Comments',
            nextTooltip: 'Next',
            resetZoomLabel: 'Reset',
          ),
        ),
      ),
    );

    final slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.divisions, isNull);
  });

  testWidgets('floating reset button blends into its measured bar target', (
    tester,
  ) async {
    var controlsVisible = false;
    late StateSetter updateControls;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              updateControls = setState;
              return ReaderBottomControls(
                controlsVisible: controlsVisible,
                readerTheme: ThemeData.dark(),
                pageIndexNotifier: ValueNotifier<int>(0),
                sliderDragging: false,
                sliderDragValue: 0,
                imageCount: 1,
                chapterPanelLoading: false,
                onSliderChangeStart: null,
                onSliderPointerDown: null,
                onSliderChanged: null,
                onSliderChangeEnd: null,
                onOpenChaptersPanel: () {},
                onPreviousChapter: () {},
                onNextChapter: () {},
                onResetZoom: () {},
                isZoomed: true,
                previousTooltip: 'Previous',
                chaptersTooltip: 'Chapters',
                favoriteTooltip: 'Favorite',
                commentsTooltip: 'Comments',
                nextTooltip: 'Next',
                resetZoomLabel: 'Reset',
              );
            },
          ),
        ),
      ),
    );

    const floatingKey = ValueKey<String>('reader_floating_reset_zoom_button');
    const targetKey = ValueKey<String>('reader_embedded_reset_zoom_button');
    final floatingFinder = find.byKey(floatingKey);
    final targetFinder = find.byKey(targetKey);
    expect(floatingFinder, findsOneWidget);
    expect(targetFinder, findsOneWidget);

    updateControls(() => controlsVisible = true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 180));

    final floatingOpacity = tester
        .widgetList<Opacity>(
          find.ancestor(of: floatingFinder, matching: find.byType(Opacity)),
        )
        .single
        .opacity;
    final targetOpacity = tester
        .widgetList<Opacity>(
          find.ancestor(of: targetFinder, matching: find.byType(Opacity)),
        )
        .single
        .opacity;
    expect(floatingOpacity + targetOpacity, closeTo(1, 0.001));

    final barAnimation = tester.widget<TweenAnimationBuilder<double>>(
      find.byKey(
        const ValueKey<String>('reader_bottom_control_bar_transition'),
      ),
    );
    expect(barAnimation.duration, const Duration(milliseconds: 360));
    expect(barAnimation.curve, Curves.easeOutBack);

    await tester.pumpAndSettle();
    expect(floatingFinder, findsOneWidget);
    expect(
      tester
          .widgetList<Opacity>(
            find.ancestor(of: floatingFinder, matching: find.byType(Opacity)),
          )
          .single
          .opacity,
      0,
    );
    expect(targetFinder, findsOneWidget);
  });

  testWidgets('rapid control toggles keep the floating reset button visible', (
    tester,
  ) async {
    var controlsVisible = false;
    late StateSetter updateControls;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              updateControls = setState;
              return ReaderBottomControls(
                controlsVisible: controlsVisible,
                readerTheme: ThemeData.dark(),
                pageIndexNotifier: ValueNotifier<int>(0),
                sliderDragging: false,
                sliderDragValue: 0,
                imageCount: 1,
                chapterPanelLoading: false,
                onSliderChangeStart: null,
                onSliderPointerDown: null,
                onSliderChanged: null,
                onSliderChangeEnd: null,
                onOpenChaptersPanel: () {},
                onPreviousChapter: () {},
                onNextChapter: () {},
                onResetZoom: () {},
                isZoomed: true,
                previousTooltip: 'Previous',
                chaptersTooltip: 'Chapters',
                favoriteTooltip: 'Favorite',
                commentsTooltip: 'Comments',
                nextTooltip: 'Next',
                resetZoomLabel: 'Reset',
              );
            },
          ),
        ),
      ),
    );

    const floatingKey = ValueKey<String>('reader_floating_reset_zoom_button');
    updateControls(() => controlsVisible = true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));
    final opacityBeforeInterrupt = tester
        .widgetList<Opacity>(
          find.ancestor(
            of: find.byKey(floatingKey),
            matching: find.byType(Opacity),
          ),
        )
        .single
        .opacity;
    updateControls(() => controlsVisible = false);
    await tester.pump();
    expect(
      tester
          .widgetList<Opacity>(
            find.ancestor(
              of: find.byKey(floatingKey),
              matching: find.byType(Opacity),
            ),
          )
          .single
          .opacity,
      closeTo(opacityBeforeInterrupt, 0.001),
    );
    await tester.pump(const Duration(milliseconds: 40));
    updateControls(() => controlsVisible = true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    updateControls(() => controlsVisible = false);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byKey(floatingKey), findsOneWidget);
    final transitionOpacities = tester
        .widgetList<Opacity>(
          find.ancestor(
            of: find.byKey(floatingKey),
            matching: find.byType(Opacity),
          ),
        )
        .map((widget) => widget.opacity);
    expect(transitionOpacities.every((opacity) => opacity == 1), isTrue);

    updateControls(() => controlsVisible = true);
    await tester.pumpAndSettle();
    expect(find.byKey(floatingKey), findsOneWidget);

    updateControls(() => controlsVisible = false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    final restoredOpacity = tester
        .widgetList<Opacity>(
          find.ancestor(
            of: find.byKey(floatingKey),
            matching: find.byType(Opacity),
          ),
        )
        .single
        .opacity;
    expect(restoredOpacity, greaterThan(0));
    expect(restoredOpacity, lessThan(1));
  });

  testWidgets('track tap commits the latest changed slider value', (
    tester,
  ) async {
    final runtimeState = ReaderRuntimeState()
      ..applyImages(List<String>.generate(12, (index) => 'img$index'))
      ..controlsVisible = true
      ..currentPageIndex = 2;
    runtimeState.setDisplayedPageIndex(2);
    final requestedPages = <int>[];

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return buildReaderBottomControls(
                context: context,
                runtimeState: runtimeState,
                readerTheme: ThemeData.dark(),
                chapterPanelLoading: false,
                maybeTriggerSliderHaptic: (_, {force = false}) {},
                updateState: (update) => update(),
                goToPage: (target) async {
                  requestedPages.add(target);
                },
                onOpenChaptersPanel: () async {},
                onPreviousChapter: () {},
                onNextChapter: () {},
                onResetZoom: () {},
              );
            },
          ),
        ),
      ),
    );

    final sliderFinder = find.byType(Slider);
    final slider = tester.widget<Slider>(sliderFinder);
    final pointerListener = tester.widget<Listener>(
      find.ancestor(of: sliderFinder, matching: find.byType(Listener)).first,
    );

    slider.onChangeStart?.call(2);
    pointerListener.onPointerDown?.call(
      const PointerDownEvent(position: Offset(10000, 0)),
    );
    slider.onChangeEnd?.call(2);
    await tester.pump();

    expect(requestedPages, [11]);
    expect(runtimeState.sliderDragging, isFalse);
    expect(runtimeState.sliderDragValue, 11);
  });
}
