import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/app/app.dart';
import 'package:hazuki/features/discover/view/discover_page_section_block.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:mocktail/mocktail.dart';

class _MockSourceDiscoverGateway extends Mock
    implements SourceDiscoverGateway {}

const _section = ExploreSection(
  title: 'Recommended',
  comics: [
    ExploreComic(
      id: 'comic-1',
      title: 'Comic one',
      subTitle: 'Author one',
      cover: '',
    ),
    ExploreComic(
      id: 'comic-2',
      title: 'Comic two',
      subTitle: 'Author two',
      cover: '',
    ),
    ExploreComic(
      id: 'comic-3',
      title: 'Comic three',
      subTitle: 'Author three',
      cover: '',
    ),
  ],
);

void main() {
  testWidgets('uses each selected mobile discover section layout', (
    tester,
  ) async {
    for (final layout in DiscoverSectionLayout.values) {
      await tester.pumpWidget(
        _buildSubject(layout: layout, platform: TargetPlatform.android),
      );

      final expectedSuffix = switch (layout) {
        DiscoverSectionLayout.horizontal => 'horizontal',
        DiscoverSectionLayout.list => 'list',
        DiscoverSectionLayout.grid2 => 'grid2',
        DiscoverSectionLayout.grid3 => 'grid3',
      };
      expect(
        find.byKey(
          PageStorageKey<String>(
            'discover-section-$expectedSuffix-0-Recommended',
          ),
        ),
        findsOneWidget,
      );

      if (layout == DiscoverSectionLayout.grid2 ||
          layout == DiscoverSectionLayout.grid3) {
        final grid = tester.widget<GridView>(find.byType(GridView));
        final delegate =
            grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
        expect(
          delegate.crossAxisCount,
          layout == DiscoverSectionLayout.grid2 ? 2 : 3,
        );
      } else if (layout == DiscoverSectionLayout.list) {
        expect(tester.getSize(find.byType(Hero).first), const Size(88, 124));
      }
    }
  });

  testWidgets('uses an adaptive cover wall on Windows', (tester) async {
    await tester.pumpWidget(
      _buildSubject(
        layout: DiscoverSectionLayout.list,
        platform: TargetPlatform.windows,
      ),
    );

    final grid = tester.widget<GridView>(find.byType(GridView));
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithMaxCrossAxisExtent;
    expect(delegate.maxCrossAxisExtent, 170);
    expect(
      find.byKey(
        const PageStorageKey<String>('discover-section-adaptive-0-Recommended'),
      ),
      findsOneWidget,
    );
  });
}

Widget _buildSubject({
  required DiscoverSectionLayout layout,
  required TargetPlatform platform,
}) {
  return MaterialApp(
    theme: ThemeData(platform: platform),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: DiscoverSectionBlock(
          section: _section,
          sectionIndex: 0,
          layout: layout,
          loadingMore: false,
          hasMore: false,
          onLoadMore: () async {},
          comicDetailPageBuilder: (_, _) => const SizedBox.shrink(),
          comicCoverHeroTagBuilder: (comic, {salt = ''}) => '${comic.id}-$salt',
          sourceService: _MockSourceDiscoverGateway(),
        ),
      ),
    ),
  );
}
