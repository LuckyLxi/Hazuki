import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/app/windows_comic_detail.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/pages/discover/discover_page.dart';
import 'package:hazuki/services/discover_daily_recommendation_service.dart';

const double _selectedIndicatorRenderWidth = 28;
const double _unselectedIndicatorRenderWidth = 14;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    WindowsComicDetailController.instance.close();
  });

  group('Discover daily recommendation carousel', () {
    testWidgets(
      'renders carousel and indicator count for multiple recommendations',
      (tester) async {
        final recommendations = <DiscoverDailyRecommendationEntry>[
          _recommendation('1', 'Author 1', 'Comic 1'),
          _recommendation('2', 'Author 2', 'Comic 2'),
          _recommendation('3', 'Author 3', 'Comic 3'),
        ];

        await tester.pumpWidget(_buildDiscoverPage(recommendations));

        expect(
          find.byKey(const ValueKey('discover_daily_recommendation_page_view')),
          findsOneWidget,
        );
        expect(find.text('Comic 1'), findsOneWidget);
        expect(find.text('Author 1'), findsOneWidget);

        for (var index = 0; index < recommendations.length; index++) {
          expect(
            find.byKey(
              ValueKey('discover_daily_recommendation_indicator_$index'),
            ),
            findsOneWidget,
          );
        }
      },
    );

    testWidgets('auto play advances indicator after one cycle', (tester) async {
      final recommendations = <DiscoverDailyRecommendationEntry>[
        _recommendation('1', 'Author 1', 'Comic 1'),
        _recommendation('2', 'Author 2', 'Comic 2'),
      ];

      await tester.pumpWidget(_buildDiscoverPage(recommendations));
      await _moveMouseAway(tester);

      expect(_indicatorWidth(tester, 0), _selectedIndicatorRenderWidth);
      expect(_indicatorWidth(tester, 1), _unselectedIndicatorRenderWidth);

      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 250));

      expect(_indicatorWidth(tester, 0), _unselectedIndicatorRenderWidth);
      expect(_indicatorWidth(tester, 1), _selectedIndicatorRenderWidth);
    });

    testWidgets('loop boundary returns indicator to first item', (
      tester,
    ) async {
      final recommendations = <DiscoverDailyRecommendationEntry>[
        _recommendation('1', 'Author 1', 'Comic 1'),
        _recommendation('2', 'Author 2', 'Comic 2'),
      ];

      await tester.pumpWidget(_buildDiscoverPage(recommendations));
      await _moveMouseAway(tester);

      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 250));

      expect(_indicatorWidth(tester, 0), _selectedIndicatorRenderWidth);
      expect(_indicatorWidth(tester, 1), _unselectedIndicatorRenderWidth);
    });

    testWidgets('manual swipe past the last item loops without losing state', (
      tester,
    ) async {
      final recommendations = <DiscoverDailyRecommendationEntry>[
        _recommendation('1', 'Author 1', 'Comic 1'),
        _recommendation('2', 'Author 2', 'Comic 2'),
      ];

      await tester.pumpWidget(_buildDiscoverPage(recommendations));
      await _moveMouseAway(tester);

      final carousel = find.byKey(
        const ValueKey('discover_daily_recommendation_page_view'),
      );

      await tester.drag(carousel, const Offset(-500, 0));
      await tester.pumpAndSettle();

      expect(_indicatorWidth(tester, 0), _unselectedIndicatorRenderWidth);
      expect(_indicatorWidth(tester, 1), _selectedIndicatorRenderWidth);

      await tester.drag(carousel, const Offset(-500, 0));
      await tester.pumpAndSettle();

      expect(_indicatorWidth(tester, 0), _selectedIndicatorRenderWidth);
      expect(_indicatorWidth(tester, 1), _unselectedIndicatorRenderWidth);
    });

    testWidgets('single recommendation does not auto play', (tester) async {
      await tester.pumpWidget(
        _buildDiscoverPage(<DiscoverDailyRecommendationEntry>[
          _recommendation('1', 'Author 1', 'Comic 1'),
        ]),
      );

      expect(_indicatorWidth(tester, 0), _selectedIndicatorRenderWidth);

      await tester.pump(const Duration(seconds: 6));
      await tester.pump();

      expect(_indicatorWidth(tester, 0), _selectedIndicatorRenderWidth);
    });

    testWidgets('tapping recommendation still opens comic detail path', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildDiscoverPage(<DiscoverDailyRecommendationEntry>[
          _recommendation('1', 'Author 1', 'Comic 1'),
        ]),
      );

      await tester.tap(find.text('Comic 1'));
      await tester.pumpAndSettle();

      if (useWindowsComicDetailPanel) {
        expect(WindowsComicDetailController.instance.entry?.comic.id, '1');
      } else {
        expect(find.text('detail:1'), findsOneWidget);
      }
    });
  });
}

Widget _buildDiscoverPage(
  List<DiscoverDailyRecommendationEntry> recommendations,
) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: DiscoverPage(
        comicDetailPageBuilder: (comic, heroTag) =>
            Scaffold(body: Center(child: Text('detail:${comic.id}'))),
        usePinnedSearchInAppBar: true,
        dailyRecommendations: recommendations,
        allowInitialLoad: false,
        hideLoadingUntilInitialLoadAllowed: true,
      ),
    ),
  );
}

DiscoverDailyRecommendationEntry _recommendation(
  String id,
  String author,
  String title,
) {
  return DiscoverDailyRecommendationEntry(
    author: author,
    comic: ExploreComic(
      id: id,
      title: title,
      subTitle: 'Subtitle $id',
      cover: '',
    ),
  );
}

double _indicatorWidth(WidgetTester tester, int index) {
  return tester
      .getSize(
        find.byKey(ValueKey('discover_daily_recommendation_indicator_$index')),
      )
      .width;
}

Future<void> _moveMouseAway(WidgetTester tester) async {
  final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await gesture.addPointer(location: const Offset(1000, 1000));
  await gesture.moveTo(const Offset(1000, 1000));
  addTearDown(gesture.removePointer);
  await tester.pump();
}
