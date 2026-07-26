import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/search/view/search_results_widgets.dart';
import 'package:hazuki/models/hazuki_models.dart';

void main() {
  testWidgets('shows tags for Picacg search results only', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SearchComicListItem(
            comic: const ExploreComic(
              id: 'picacg-comic',
              title: 'Picacg comic',
              subTitle: 'Author',
              cover: '',
              sourceKey: 'picacg',
              tags: ['Action', 'Romance'],
            ),
            heroTag: 'picacg-comic',
            index: 0,
            onTap: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Action'), findsOneWidget);
    expect(find.text('Romance'), findsOneWidget);
  });

  testWidgets('does not show tags for other sources', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SearchComicListItem(
            comic: const ExploreComic(
              id: 'other-comic',
              title: 'Other comic',
              subTitle: '',
              cover: '',
              sourceKey: 'jm',
              tags: ['Hidden tag'],
            ),
            heroTag: 'other-comic',
            index: 0,
            onTap: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hidden tag'), findsNothing);
  });
}
