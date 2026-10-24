import '../../support/fake_source_task_control.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/home/state/home_coordinator.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/services/announcements/announcement_controller.dart';
import 'package:hazuki/services/discover_daily_recommendation_service.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Source extends Mock implements SourceHomeGateway {}

class _Switch extends Mock implements SourceRuntimeGateway {}

class _Images extends Mock implements SourceImageGateway {}

class _Recommendations extends Mock
    implements DiscoverDailyRecommendationService {}

class _Announcements extends Mock implements AnnouncementController {}

class _RuntimeScope extends InheritedNotifier<ValueNotifier<int>> {
  const _RuntimeScope({required super.notifier, required super.child});
}

class _StartOnInit extends StatefulWidget {
  const _StartOnInit({required this.coordinator});
  final HomeCoordinator coordinator;

  @override
  State<_StartOnInit> createState() => _StartOnInitState();
}

class _StartOnInitState extends State<_StartOnInit> {
  @override
  void initState() {
    super.initState();
    widget.coordinator.start(context);
  }

  @override
  Widget build(BuildContext context) {
    context.dependOnInheritedWidgetOfExactType<_RuntimeScope>();
    return const SizedBox();
  }
}

void main() {
  for (final publishReady in [true, false]) {
    testWidgets(
      'login runtime recreation updates sidebar (ready notification=$publishReady)',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final source = _Source();
        final recommendations = _Recommendations();
        late VoidCallback sourceChanged;
        var initialized = true;
        var loggedIn = false;
        when(() => source.addListener(any())).thenAnswer((invocation) {
          sourceChanged = invocation.positionalArguments.single as VoidCallback;
        });
        when(() => source.activeSourceKey).thenReturn('source');
        when(() => source.sourceRevision).thenReturn('source|1.0');
        when(() => source.isInitialized).thenAnswer((_) => initialized);
        when(() => source.isLogged).thenAnswer((_) => loggedIn);
        when(
          () => source.currentAccount,
        ).thenAnswer((_) => loggedIn ? 'New user' : null);
        when(() => source.isActiveDailyCheckInSource).thenReturn(false);
        when(
          () => source.runtimeState,
        ).thenReturn(const SourceRuntimeState.idle());
        when(source.loadActiveSourcePreference).thenAnswer((_) async {});
        when(source.prewarmInBackground).thenAnswer((_) async {});
        when(source.warmUpFavoritesDebugInfo).thenAnswer((_) async {});
        when(
          () =>
              source.loadCurrentAvatarUrl(taskOrigin: any(named: 'taskOrigin')),
        ).thenAnswer((_) async {
          initialized = true;
          if (publishReady) sourceChanged();
          return 'https://example/new-avatar';
        });
        when(recommendations.loadEnabled).thenAnswer((_) async => false);
        when(() => recommendations.ensurePrepared(enabled: false)).thenAnswer(
          (_) async => const DiscoverDailyRecommendationState.disabled(),
        );
        final coordinator = HomeCoordinator(
          initialTabIndex: 0,
          sourceService: source,
          sourceSwitchService: _Switch(),
          imageService: _Images(),
          dailyRecommendationService: recommendations,
          announcementService: _Announcements(),
          taskControl: FakeSourceTaskControl(),
        );
        addTearDown(coordinator.dispose);
        late BuildContext context;
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (value) {
                context = value;
                return AnimatedBuilder(
                  animation: coordinator,
                  builder: (_, _) => Text(
                    coordinator.profileLoading
                        ? 'loading'
                        : coordinator.username,
                  ),
                );
              },
            ),
          ),
        );
        coordinator.start(context);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        final profile = await coordinator
            .createProfileFlow(context, isMounted: () => context.mounted)
            .handleLoginSubmit(
              'account',
              'password',
              loginOverride: ({required account, required password}) async {
                // Interactive login replaces the handle without changing sourceRevision.
                initialized = false;
                loggedIn = true;
                sourceChanged();
              },
            );
        await tester.pump();
        expect(profile.username, 'New user');
        expect(profile.avatarUrl, 'https://example/new-avatar');
        expect(coordinator.profileLoading, isFalse);
        expect(coordinator.username, profile.username);
        expect(coordinator.avatarUrl, profile.avatarUrl);
        expect(find.text('loading'), findsNothing);
        await tester.pump(const Duration(seconds: 4));
      },
    );
  }

  testWidgets(
    'starting from initState does not notify runtime listeners during build',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final source = _Source();
      final recommendations = _Recommendations();
      // 模拟真实预热：在首个 await 之前同步发出运行时状态通知。
      final runtime = ValueNotifier<int>(0);
      addTearDown(runtime.dispose);
      when(() => source.addListener(any())).thenAnswer((_) {});
      when(() => source.activeSourceKey).thenReturn('source');
      when(() => source.isInitialized).thenReturn(true);
      when(() => source.isLogged).thenReturn(false);
      when(() => source.currentAccount).thenReturn(null);
      when(() => source.isActiveDailyCheckInSource).thenReturn(false);
      when(
        () => source.runtimeState,
      ).thenReturn(const SourceRuntimeState.idle());
      when(source.loadActiveSourcePreference).thenAnswer((_) async {});
      when(source.prewarmInBackground).thenAnswer((_) {
        runtime.value++;
        return Future.value();
      });
      when(recommendations.loadEnabled).thenAnswer((_) async => false);
      when(() => recommendations.ensurePrepared(enabled: false)).thenAnswer(
        (_) async => const DiscoverDailyRecommendationState.disabled(),
      );
      final coordinator = HomeCoordinator(
        initialTabIndex: 0,
        sourceService: source,
        sourceSwitchService: _Switch(),
        imageService: _Images(),
        dailyRecommendationService: recommendations,
        announcementService: _Announcements(),
        taskControl: FakeSourceTaskControl(),
      );
      addTearDown(coordinator.dispose);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: _RuntimeScope(
            notifier: runtime,
            child: _StartOnInit(coordinator: coordinator),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      verify(source.prewarmInBackground).called(1);
      expect(runtime.value, 1);
      await tester.pump(const Duration(seconds: 4));
    },
  );

  for (final succeeds in [true, false]) {
    testWidgets('startup profile follows initialization success=$succeeds', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final source = _Source();
      final recommendations = _Recommendations();
      final prewarm = Completer<void>();
      late VoidCallback sourceChanged;
      when(() => source.addListener(any())).thenAnswer((invocation) {
        sourceChanged = invocation.positionalArguments.single as VoidCallback;
      });
      when(() => source.activeSourceKey).thenReturn('source');
      when(() => source.isInitialized).thenReturn(false);
      when(() => source.isLogged).thenReturn(true);
      when(() => source.currentAccount).thenReturn('User');
      when(() => source.isActiveDailyCheckInSource).thenReturn(false);
      when(
        () => source.runtimeState,
      ).thenReturn(const SourceRuntimeState.idle());
      when(source.loadActiveSourcePreference).thenAnswer((_) async {});
      when(source.prewarmInBackground).thenAnswer((_) => prewarm.future);
      when(source.warmUpFavoritesDebugInfo).thenAnswer((_) async {});
      when(
        () => source.loadCurrentAvatarUrl(taskOrigin: any(named: 'taskOrigin')),
      ).thenAnswer((_) async => 'avatar');
      when(recommendations.loadEnabled).thenAnswer((_) async => false);
      when(() => recommendations.ensurePrepared(enabled: false)).thenAnswer(
        (_) async => const DiscoverDailyRecommendationState.disabled(),
      );
      final coordinator = HomeCoordinator(
        initialTabIndex: 0,
        sourceService: source,
        sourceSwitchService: _Switch(),
        imageService: _Images(),
        dailyRecommendationService: recommendations,
        announcementService: _Announcements(),
        taskControl: FakeSourceTaskControl(),
      );
      addTearDown(coordinator.dispose);
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (value) {
              context = value;
              return const SizedBox();
            },
          ),
        ),
      );
      coordinator.start(context);
      await tester.pump();
      expect(coordinator.profileLoading, isTrue);

      when(() => source.isInitialized).thenReturn(succeeds);
      if (!succeeds) {
        when(() => source.runtimeState).thenReturn(
          const SourceRuntimeState(
            phase: SourceRuntimePhase.failed,
            step: SourceRuntimeStep.none,
            statusText: 'failed',
            updatedAt: null,
          ),
        );
      }
      sourceChanged();
      await tester.pump();
      // The runtime notification must work without waiting for prewarm's caller.
      expect(coordinator.profileLoading, isFalse);
      expect(coordinator.username, 'User');
      expect(coordinator.avatarUrl, succeeds ? 'avatar' : isNull);
      prewarm.complete();
      await tester.pump();
    });
  }
}
