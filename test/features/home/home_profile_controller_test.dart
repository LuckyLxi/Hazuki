import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/home/state/home_profile_controller.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:mocktail/mocktail.dart';

class _Source extends Mock implements SourceHomeGateway {}

void main() {
  late _Source source;
  late HomeProfileController controller;
  late BuildContext context;

  setUp(() {
    source = _Source();
    when(() => source.activeSourceKey).thenReturn('source');
    when(() => source.isInitialized).thenReturn(true);
    when(() => source.isLogged).thenReturn(true);
    when(() => source.currentAccount).thenReturn('login-id');
    when(() => source.cachedAvatarUrl).thenReturn('https://example/cached');
    when(() => source.isActiveDailyCheckInSource).thenReturn(false);
    when(source.loadActiveSourcePreference).thenAnswer((_) async {});
    controller = HomeProfileController(sourceService: source);
    addTearDown(controller.dispose);
  });

  Future<void> mount(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      locale: const Locale('zh'),
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

  testWidgets('publishes cached profile before remote refresh finishes', (
    tester,
  ) async {
    final refresh = Completer<String?>();
    when(source.loadCurrentAvatarUrl).thenAnswer((_) => refresh.future);
    await mount(tester);
    final sync = controller.syncUserProfile(context);
    await tester.pump();

    expect(controller.profileLoading, isFalse);
    expect(controller.username, 'login-id');
    expect(controller.avatarUrl, 'https://example/cached');

    when(() => source.currentAccount).thenReturn('Display Name');
    refresh.complete('https://example/new');
    await sync;
    expect(controller.username, 'Display Name');
    expect(controller.avatarUrl, 'https://example/new');
  });

  testWidgets('failed refresh retains the cached avatar and usable account', (
    tester,
  ) async {
    when(source.loadCurrentAvatarUrl).thenAnswer((_) async {
      throw StateError('offline');
    });
    await mount(tester);
    await controller.syncUserProfile(context);

    expect(controller.profileLoading, isFalse);
    expect(controller.username, 'login-id');
    expect(controller.avatarUrl, 'https://example/cached');
  });

  testWidgets('older profile sync cannot overwrite a newer sync', (
    tester,
  ) async {
    final oldRefresh = Completer<String?>();
    when(source.loadCurrentAvatarUrl).thenAnswer((_) => oldRefresh.future);
    await mount(tester);
    final oldSync = controller.syncUserProfile(context);
    await tester.pump();

    controller.markSourceChanged();
    when(() => source.activeSourceKey).thenReturn('other');
    when(() => source.currentAccount).thenReturn('Other user');
    when(source.loadCurrentAvatarUrl).thenAnswer((_) async => 'other-avatar');
    await controller.syncUserProfile(context);
    oldRefresh.complete('old-avatar');
    await oldSync;

    expect(controller.username, 'Other user');
    expect(controller.avatarUrl, 'other-avatar');
    expect(controller.profileLoading, isFalse);
  });

  testWidgets('logout discards an unfinished avatar refresh', (tester) async {
    final refresh = Completer<String?>();
    when(source.loadCurrentAvatarUrl).thenAnswer((_) => refresh.future);
    await mount(tester);
    final sync = controller.syncUserProfile(context);
    await tester.pump();

    when(() => source.isLogged).thenReturn(false);
    controller.markLoggedOut();
    refresh.complete('old-avatar');
    await sync;

    expect(controller.avatarUrl, isNull);
    expect(controller.profileLoading, isFalse);
  });

  testWidgets(
    'resolved login profile replaces loading and supersedes old sync',
    (tester) async {
      final refresh = Completer<String?>();
      when(source.loadCurrentAvatarUrl).thenAnswer((_) => refresh.future);
      await mount(tester);
      final sync = controller.syncUserProfile(context);
      await tester.pump();

      controller.markAuthChanged();
      expect(controller.profileLoading, isTrue);
      controller.applyLoginProfile(
        username: 'Dialog user',
        avatarUrl: 'https://example/dialog-avatar',
      );
      refresh.complete('old-avatar');
      await sync;

      expect(controller.username, 'Dialog user');
      expect(controller.avatarUrl, 'https://example/dialog-avatar');
      expect(controller.profileLoading, isFalse);
    },
  );
}
