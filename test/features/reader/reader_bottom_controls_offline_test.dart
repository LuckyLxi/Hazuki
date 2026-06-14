import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/reader/view/reader_bottom_controls.dart';

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
}
