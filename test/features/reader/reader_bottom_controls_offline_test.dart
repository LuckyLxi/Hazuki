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
