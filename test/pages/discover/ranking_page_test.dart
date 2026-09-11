import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/discover/view/ranking_page.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/shared/windows/windows_comic_detail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/test_service_locator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(const {});
    await ensureTestServiceLocator();
  });

  tearDown(() {
    WindowsComicDetailController.instance.close();
  });

  testWidgets('starts initial ranking load after first build', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: RankingPage(
          sourceService: _FakeRankingSource(),
          comicDetailPageBuilder: (_, _) => const SizedBox.shrink(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Rankings'), findsOneWidget);
    final opacityFinder = find.byKey(
      const ValueKey('ranking-list-entry-opacity--comic-0'),
    );
    final opacity = tester.widget<Opacity>(opacityFinder).opacity;
    expect(opacity, greaterThan(0));
    expect(opacity, lessThan(1));
    final transform = tester.widget<Transform>(
      find.ancestor(of: opacityFinder, matching: find.byType(Transform)).first,
    );
    expect(transform.transform.storage[12], lessThan(0));
    expect(transform.transform.storage[13], 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('animates and restores the selected ranking comic layout', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: RankingPage(
          sourceService: _FakeRankingSource(),
          comicDetailPageBuilder: (_, _) => const SizedBox.shrink(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('ranking-layout-button')));
    await tester.pump();

    expect(find.text('Comic layout'), findsOneWidget);
    expect(find.text('Vertical list'), findsOneWidget);
    expect(find.text('3-column grid'), findsOneWidget);
    expect(
      find.ancestor(
        of: find.text('Comic layout'),
        matching: find.byType(FadeTransition),
      ),
      findsWidgets,
    );
    await tester.pump(const Duration(milliseconds: 300));
    final dialogRoute = ModalRoute.of(
      tester.element(find.text('Comic layout')),
    )!;
    expect(dialogRoute.transitionDuration, const Duration(milliseconds: 240));

    await tester.tap(find.byKey(const ValueKey('ranking-layout-grid3')));
    expect(dialogRoute.animation!.status, AnimationStatus.reverse);
    await tester.pump();

    final button = tester.widget<IconButton>(
      find.byKey(const ValueKey('ranking-layout-button')),
    );
    expect((button.icon as Icon).icon, Icons.apps_rounded);
    expect(find.byKey(const ValueKey('ranking-comic-grid3')), findsOneWidget);
    final initialOpacity = tester.widget<Opacity>(
      find.byKey(const ValueKey('ranking-grid-entry-opacity-0')),
    );
    expect(initialOpacity.opacity, lessThan(1));

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Comic layout'), findsNothing);
    final completedOpacity = tester.widget<Opacity>(
      find.byKey(const ValueKey('ranking-grid-entry-opacity-0')),
    );
    expect(completedOpacity.opacity, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: RankingPage(
          sourceService: _FakeRankingSource(),
          comicDetailPageBuilder: (_, _) => const SizedBox.shrink(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    final restoredButton = tester.widget<IconButton>(
      find.byKey(const ValueKey('ranking-layout-button')),
    );
    expect((restoredButton.icon as Icon).icon, Icons.apps_rounded);
    expect(find.byKey(const ValueKey('ranking-comic-grid3')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakeRankingSource implements SourceCategoryGateway {
  @override
  bool get softwareLogCaptureEnabled => false;

  @override
  Future<List<CategoryRankingOption>> loadCategoryRankingOptions() async =>
      const [CategoryRankingOption(value: 'all', label: 'All')];

  @override
  Future<CategoryComicsResult> loadCategoryRankingComics({
    required String rankingOption,
    required int page,
  }) async => CategoryComicsResult(
    maxPage: 1,
    comics: List.generate(
      3,
      (index) => ExploreComic(
        id: 'comic-$index',
        title: 'Comic $index',
        subTitle: 'Subtitle $index',
        cover: '',
      ),
    ),
  );

  @override
  Future<List<CategoryTagGroup>> loadCategoryTagGroups({
    bool forceRefresh = false,
    String sourceKey = '',
  }) async => const [];

  @override
  void addApplicationLog({
    required String level,
    required String title,
    Object? content,
    String source = 'app',
  }) {}
}
