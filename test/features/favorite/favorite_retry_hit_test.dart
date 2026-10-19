import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/favorite/view/favorite_comic_tile.dart';
import 'package:hazuki/features/favorite/view/favorite_page_content.dart';
import 'package:hazuki/features/favorite/view/favorite_view_support.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/source/source_capabilities.dart';

void main() {
  for (final animationStyle in FavoriteEntryAnimationStyle.values) {
    testWidgets(
      'outgoing list preserves state and ignores taps ($animationStyle)',
      (tester) async {
        final showError = ValueNotifier(false);
        addTearDown(showError.dispose);
        var comicTaps = 0;
        var retries = 0;
        const comics = [
          ExploreComic(
            id: 'one',
            sourceKey: 'jm',
            title: 'One',
            subTitle: '',
            cover: '',
          ),
          ExploreComic(
            id: 'two',
            sourceKey: 'jm',
            title: 'Two',
            subTitle: '',
            cover: '',
          ),
          ExploreComic(
            id: 'three',
            sourceKey: 'jm',
            title: 'Three',
            subTitle: '',
            cover: '',
          ),
        ];

        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                child: ValueListenableBuilder(
                  valueListenable: showError,
                  builder: (context, error, _) => FavoritePageContentSection(
                    comics: error ? const [] : comics,
                    comicAnimationStyles: {
                      for (final comic in comics) comic.id: animationStyle,
                    },
                    errorMessage: error ? 'Network error' : null,
                    initialLoading: false,
                    refreshing: false,
                    loadingMore: false,
                    sourceRuntimeState: const SourceRuntimeState.idle(),
                    strings: AppLocalizations.of(context)!,
                    onRetry: () async => retries++,
                    showCreateLocalFolderButton: false,
                    onComicTap: (_) => comicTaps++,
                    mode: FavoritePageMode.cloud,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final outgoingTile = find.widgetWithText(FavoriteComicTile, 'Three');
        final outgoingState = tester.state(outgoingTile);
        final oldComicPosition = tester.getCenter(find.text('Three'));

        showError.value = true;
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 80));
        // The old list is still painted during the existing fade animation.
        expect(find.text('Three'), findsOneWidget);
        expect(tester.state(outgoingTile), same(outgoingState));
        if (animationStyle == FavoriteEntryAnimationStyle.staggered) {
          final entryOpacity = tester.widget<FadeTransition>(
            find.descendant(
              of: outgoingTile,
              matching: find.byType(FadeTransition),
            ),
          );
          expect(entryOpacity.opacity.value, 1);
        }
        await tester.tap(find.text('Network error'), warnIfMissed: false);
        await tester.tapAt(oldComicPosition);
        expect(comicTaps, 0);

        await tester.tap(find.text('重试'));
        expect(retries, 1);
        expect(comicTaps, 0);
        await tester.pumpAndSettle();
        await tester.tap(find.text('重试'));
        expect(retries, 2);
        expect(comicTaps, 0);
      },
    );
  }
}
