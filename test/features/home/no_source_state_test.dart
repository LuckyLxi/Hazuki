import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/discover/view/discover_page.dart';
import 'package:hazuki/features/favorite/view/favorite_page.dart';
import 'package:hazuki/features/home/state/home_profile_controller.dart';
import 'package:hazuki/features/home/support/home_sidebar_models.dart';
import 'package:hazuki/features/home/view/home_drawer_profile_header.dart';
import 'package:hazuki/features/home/view/home_profile_avatar.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/discover_daily_recommendation_service.dart';
import 'package:hazuki/services/local_favorites/local_favorites_contracts.dart';
import 'package:hazuki/services/local_favorites/local_favorites_preferences_store.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:mocktail/mocktail.dart';

class _Source extends Mock
    implements
        SourceDiscoverGateway,
        SourceFavoriteGateway,
        SourceHomeGateway {}

class _Recommendations extends Mock implements SourceRecommendationGateway {}

class _RecommendationService extends Mock
    implements DiscoverDailyRecommendationService {}

class _Local extends Mock implements LocalFavoritesRepository {}

class _Preferences extends Mock implements LocalFavoritesPreferencesStore {}

class _Images extends Mock implements SourceImageGateway {}

Widget _app(Widget child) => MaterialApp(
  locale: const Locale('zh'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  late _Source source;

  setUp(() {
    source = _Source();
    when(() => source.isLogged).thenReturn(false);
    when(() => source.isInitialized).thenReturn(false);
    when(source.loadActiveSourcePreference).thenAnswer((_) async {});
    when(() => source.runtimeState).thenReturn(const SourceRuntimeState.idle());
  });

  testWidgets('discover uses a larger install prompt and keeps plugin access', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        DiscoverPage(
          sourceService: source,
          recommendationSource: _Recommendations(),
          recommendationService: _RecommendationService(),
          allowInitialLoad: false,
          comicDetailPageBuilder: (_, _) => const SizedBox.shrink(),
          pluginPageBuilder: (_) => const Scaffold(body: Text('plugin-page')),
        ),
      ),
    );

    final prompt = find.text('请先安装漫画源');
    expect(prompt, findsOneWidget);
    final context = tester.element(prompt);
    expect(
      tester.widget<Text>(prompt).style!.fontSize,
      greaterThan(Theme.of(context).textTheme.bodyMedium!.fontSize!),
    );
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(find.text('plugin-page'), findsOneWidget);
  });

  testWidgets('cloud favorites show install prompt without a login button', (
    tester,
  ) async {
    final preferences = _Preferences();
    when(
      () => preferences.loadFavoritePageMode(sourceKey: ''),
    ).thenAnswer((_) async => FavoritePageMode.cloud);
    for (final mode in FavoritePageMode.values) {
      when(
        () => preferences.loadSelectedFavoriteFolderId(mode, sourceKey: ''),
      ).thenAnswer((_) async => '0');
    }
    when(
      () => source.cloudFavoritesChangedStream,
    ).thenAnswer((_) => const Stream<void>.empty());
    when(() => source.supportFavoriteSortOrder).thenReturn(false);
    when(() => source.supportFavoriteFolderAdd).thenReturn(false);
    when(() => source.favoriteSortOrders).thenReturn(const []);

    await tester.pumpWidget(
      _app(
        FavoritePage(
          sourceService: source,
          localFavoritesRepository: _Local(),
          localFavoritesPreferences: preferences,
          imageGateway: _Images(),
          authVersion: 0,
          onComicTap: (_, _) async {},
          onRequestLogin: () async => fail('Login must not be offered'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('请先安装漫画源'), findsOneWidget);
    expect(find.text('请登录'), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
    verifyNever(() => source.ensureInitialized());
  });

  for (final sourceKey in <String?>[null, '', 'installed']) {
    testWidgets('drawer profile handles uninitialized source $sourceKey', (
      tester,
    ) async {
      when(() => source.activeSourceKey).thenReturn(sourceKey);
      final controller = HomeProfileController(sourceService: source);
      addTearDown(controller.dispose);
      late BuildContext profileContext;
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) {
              profileContext = context;
              return AnimatedBuilder(
                animation: controller,
                builder: (context, _) => HomeDrawerProfileHeader(
                  profile: HomeSidebarProfileState(
                    isLogged: controller.isLogged,
                    profileLoading: controller.profileLoading,
                    avatarUrl: controller.avatarUrl,
                    username: controller.username,
                    autoCheckInEnabled: false,
                    showCheckInActions: false,
                    checkInBusy: false,
                    checkedInToday: controller.checkedInToday,
                  ),
                  actions: const HomeSidebarActions(),
                  activeSourceKey: sourceKey ?? '',
                  backgroundColor: Theme.of(context).colorScheme.surface,
                ),
              );
            },
          ),
        ),
      );

      await controller.syncUserProfile(profileContext);
      await tester.pump();

      final hasSource = sourceKey == 'installed';
      expect(controller.profileLoading, hasSource);
      expect(find.text(hasSource ? '加载中...' : '未登录'), findsOneWidget);
      expect(
        tester
            .widget<HomeProfileAvatar>(find.byType(HomeProfileAvatar))
            .loading,
        hasSource,
      );
      verifyNever(source.loadCurrentAvatarUrl);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
