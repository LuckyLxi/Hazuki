import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/favorite/view/favorite_comic_tile.dart';
import 'package:hazuki/features/favorite/view/favorite_page_content.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/shared/appearance/appearance_settings.dart';

final _comics = List.generate(
  6,
  (index) => ExploreComic(
    id: 'comic-$index',
    sourceKey: 'test',
    title: 'Comic $index with a long title to wrap across multiple lines',
    subTitle: 'Author $index',
    cover: '',
  ),
);

Widget _app({
  required FavoriteLayout layout,
  required ValueChanged<ExploreComic> onTap,
  FavoritePageMode mode = FavoritePageMode.local,
  double textScale = 1,
}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: SingleChildScrollView(
          child: FavoritePageContentSection(
            layout: layout,
            comics: _comics,
            comicAnimationStyles: const {},
            errorMessage: null,
            initialLoading: false,
            refreshing: false,
            loadingMore: false,
            sourceRuntimeState: const SourceRuntimeState.idle(),
            strings: AppLocalizations.of(context)!,
            onRetry: () async {},
            showCreateLocalFolderButton: false,
            onComicTap: onTap,
            mode: mode,
          ),
        ),
      ),
    ),
  ),
);

void main() {
  for (final mode in FavoritePageMode.values) {
    for (final layout in FavoriteLayout.values) {
      testWidgets('$mode renders $layout and opens the selected comic', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        ExploreComic? tapped;
        await tester.pumpWidget(
          _app(layout: layout, mode: mode, onTap: (comic) => tapped = comic),
        );
        await tester.pumpAndSettle();

        final first = find.byType(FavoriteComicTile).at(0);
        final second = find.byType(FavoriteComicTile).at(1);
        if (layout == FavoriteLayout.list) {
          expect(
            tester.getTopLeft(second).dy,
            greaterThan(tester.getTopLeft(first).dy),
          );
          expect(find.text('Author 0'), findsOneWidget);
        } else {
          expect(tester.getTopLeft(second).dy, tester.getTopLeft(first).dy);
          expect(
            tester.getTopLeft(second).dx,
            greaterThan(tester.getTopLeft(first).dx),
          );
          final nextRow = find.byType(FavoriteComicTile).at(layout.columns);
          expect(
            tester.getTopLeft(nextRow).dy,
            greaterThan(tester.getTopLeft(first).dy),
          );
          expect(find.text('Author 0'), findsNothing);
          final grid = tester.widget<GridView>(
            find.byKey(const ValueKey('favorite-grid')),
          );
          expect(
            (grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
                .crossAxisCount,
            layout.columns,
          );
        }
        expect(
          find.text(_comics.first.title),
          layout == FavoriteLayout.coverOnly ? findsNothing : findsOneWidget,
        );
        await tester.tap(first);
        expect(tapped, same(_comics.first));
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('switches layouts without duplicate cover Heroes or overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final layout in [...FavoriteLayout.values, FavoriteLayout.list]) {
      await tester.pumpWidget(
        _app(layout: layout, textScale: 2, onTap: (_) {}),
      );
      await tester.pump();
      expect(find.byType(Hero), findsNWidgets(_comics.length));
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('cover-only entries keep accessible titles and actions', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(layout: FavoriteLayout.coverOnly, onTap: (_) {}),
    );
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(_comics.first.title), findsOneWidget);
    expect(
      tester.getSemantics(find.bySemanticsLabel(_comics.first.title)),
      matchesSemantics(
        label: _comics.first.title,
        isButton: true,
        hasTapAction: true,
      ),
    );
    expect(find.text(_comics.first.title), findsNothing);
    semantics.dispose();
  });
}
