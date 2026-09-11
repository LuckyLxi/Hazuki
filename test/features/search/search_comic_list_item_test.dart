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

  testWidgets('list items fade in while sliding horizontally', (tester) async {
    const comic = ExploreComic(
      id: 'animated-list',
      title: 'Animated list comic',
      subTitle: '',
      cover: '',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SearchComicListItem(
            comic: comic,
            heroTag: 'animated-list',
            index: 0,
            onTap: () {},
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    final opacityFinder = find.byKey(
      const ValueKey('search-list-entry-opacity--animated-list'),
    );
    final opacity = tester.widget<Opacity>(opacityFinder).opacity;
    expect(opacity, greaterThan(0));
    expect(opacity, lessThan(1));
    final transform = tester.widget<Transform>(
      find.ancestor(of: opacityFinder, matching: find.byType(Transform)).first,
    );
    expect(transform.transform.storage[12], lessThan(0));
    expect(transform.transform.storage[13], 0);
  });

  testWidgets('grid items fade, rise, and scale into place', (tester) async {
    const comic = ExploreComic(
      id: 'animated-grid',
      title: 'Animated grid comic',
      subTitle: '',
      cover: '',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 120,
            height: 220,
            child: SearchComicGridItem(
              comic: comic,
              heroTag: 'animated-grid',
              index: 0,
              coverCacheWidth: 120,
              placeholderColor: Colors.grey,
              onTap: () async {},
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    final opacity = tester.widget<Opacity>(
      find.byKey(const ValueKey('search-grid-entry-opacity--animated-grid')),
    );
    expect(opacity.opacity, greaterThan(0));
    expect(opacity.opacity, lessThan(1));

    await tester.pump(const Duration(seconds: 1));
    expect(
      tester
          .widget<Opacity>(
            find.byKey(
              const ValueKey('search-grid-entry-opacity--animated-grid'),
            ),
          )
          .opacity,
      1,
    );
  });
}
