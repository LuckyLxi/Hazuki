import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/home/support/home_sidebar_models.dart';
import 'package:hazuki/features/home/view/home_profile_avatar.dart';
import 'package:hazuki/features/home/view/home_windows_sidebar.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/widgets/hazuki_m3e_loading_indicator.dart';
import 'package:mocktail/mocktail.dart';

class _Gateway extends Mock implements SourceSwitchGateway {}

const _profile = HomeSidebarProfileState(
  isLogged: false,
  profileLoading: false,
  avatarUrl: '',
  username: 'guest',
  autoCheckInEnabled: false,
  showCheckInActions: false,
  checkInBusy: false,
  checkedInToday: false,
);

void main() {
  late _Gateway gateway;
  late List<SourceCatalogEntry> sources;
  String? active;
  var switches = 0;
  final card = find.byKey(const ValueKey('windows-source-picker-card'));
  final button = find.byKey(const ValueKey('windows-sidebar-source-switch'));

  setUp(() {
    gateway = _Gateway();
    active = 'a';
    switches = 0;
    sources = [
      for (final id in ['a', 'b'])
        SourceCatalogEntry(
          key: id,
          name: 'Plugin $id',
          fileName: '$id.js',
          pluginVersion: '1.0.0',
        ),
    ];
    when(gateway.loadActiveSourcePreference).thenAnswer((_) async {});
    when(() => gateway.allowedSources).thenAnswer((_) => sources);
    when(() => gateway.activeSourceKey).thenAnswer((_) => active);
    when(() => gateway.activateSource(any())).thenAnswer((call) async {
      active = call.positionalArguments.first as String;
    });
    when(
      () => gateway.ensureInitialized(sourceKey: any(named: 'sourceKey')),
    ).thenAnswer((call) async {
      active = call.namedArguments[#sourceKey] as String?;
    });
  });

  Future<void> pumpApp(
    WidgetTester tester, {
    String locale = 'en',
    double scale = 1,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: Locale(locale),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(
          body: Row(
            children: [
              SizedBox(
                width: 80,
                child: HomeWindowsSidebar(
                  profile: _profile,
                  actions: const HomeSidebarActions(),
                  currentIndex: 0,
                  selectedDestination: null,
                  sourceSwitchService: gateway,
                  onSourceSwitched: () async => switches++,
                ),
              ),
              const Expanded(child: Center(child: Text('Home'))),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'Windows reveals and focuses a late current plugin at ${scale}x text',
      (tester) async {
        tester.view.physicalSize = const Size(640, 400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        sources = [
          for (var i = 0; i < 30; i++)
            SourceCatalogEntry(
              key: 'source_$i',
              name: 'Plugin $i',
              fileName: '$i.js',
            ),
        ];
        active = 'source_28';
        await pumpApp(tester, scale: scale);
        await tester.tap(button);
        await tester.pumpAndSettle();
        final current = find.byKey(const ValueKey('windows-source-source_28'));
        final list = find.descendant(of: card, matching: find.byType(ListView));
        expect(current.hitTestable(), findsOneWidget);
        final listBounds = tester.getRect(list);
        final itemBounds = tester.getRect(current);
        expect(itemBounds.top, greaterThanOrEqualTo(listBounds.top - 0.01));
        if (itemBounds.height <= listBounds.height) {
          expect(
            itemBounds.bottom,
            lessThanOrEqualTo(listBounds.bottom + 0.01),
          );
        } else {
          expect(itemBounds.top, closeTo(listBounds.top, 0.01));
          expect(find.text('Plugin 28').hitTestable(), findsOneWidget);
        }
        expect(Focus.of(tester.element(current)).hasPrimaryFocus, isTrue);
        await tester.drag(list, const Offset(0, 300));
        await tester.pumpAndSettle();
        expect(current.hitTestable(), findsNothing);
        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pumpAndSettle();
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(current.hitTestable(), findsOneWidget);
        expect(Focus.of(tester.element(current)).hasPrimaryFocus, isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('rapid repeated presses open only one card', (tester) async {
    final loading = Completer<void>();
    when(gateway.loadActiveSourcePreference).thenAnswer((_) => loading.future);
    await pumpApp(tester);
    await tester.tap(button);
    await tester.tap(button);
    loading.complete();
    await tester.pumpAndSettle();
    expect(card, findsOneWidget);
    verify(gateway.loadActiveSourcePreference).called(1);
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    expect(card, findsNothing);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(card, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'button below avatar slides the installed source card right and back',
    (tester) async {
      await pumpApp(tester);
      expect(
        tester.getTopLeft(button).dy,
        greaterThan(tester.getBottomLeft(find.byType(HomeProfileAvatar)).dy),
      );
      await tester.tap(button);
      await tester.pump();
      final start = tester.getTopLeft(card);
      final fade = find
          .ancestor(of: card, matching: find.byType(FadeTransition))
          .first;
      expect(tester.widget<FadeTransition>(fade).opacity.value, 0);
      await tester.pump(const Duration(milliseconds: 140));
      final halfway = tester.getTopLeft(card);
      expect(halfway.dx, greaterThan(start.dx));
      expect(
        tester.widget<FadeTransition>(fade).opacity.value,
        inExclusiveRange(0, 1),
      );
      await tester.pumpAndSettle();
      final end = tester.getTopLeft(card);
      expect(end.dx, greaterThanOrEqualTo(80));
      expect(end.dx, greaterThan(halfway.dx));
      expect(find.text('Plugin a'), findsOneWidget);
      expect(find.text('Plugin b'), findsOneWidget);
      expect(
        tester
            .widget<ListTile>(find.byKey(const ValueKey('windows-source-a')))
            .selected,
        isTrue,
      );
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      await tester.tapAt(const Offset(700, 500));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 140));
      expect(card, findsOneWidget);
      expect(tester.getTopLeft(card).dx, lessThan(end.dx));
      await tester.pumpAndSettle();
      expect(card, findsNothing);
      verifyNever(() => gateway.activateSource(any()));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'switching blocks dismissal, restores a failed source and allows retry',
    (tester) async {
      final pending = Completer<void>();
      when(
        () => gateway.ensureInitialized(sourceKey: 'b'),
      ).thenAnswer((_) => pending.future);
      await pumpApp(tester);
      await tester.tap(button);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Plugin b'));
      await tester.pump();
      expect(find.byType(HazukiM3ELoadingIndicator), findsOneWidget);
      expect(
        tester
            .widgetList<ListTile>(find.byType(ListTile))
            .every((tile) => !tile.enabled),
        isTrue,
      );
      await tester.tapAt(const Offset(700, 500));
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(card, findsOneWidget);
      pending.completeError(StateError('Initialization failed'));
      await tester.pumpAndSettle();
      expect(active, 'a');
      expect(switches, 0);
      expect(find.textContaining('Initialization failed'), findsOneWidget);
      expect(find.byType(HazukiM3ELoadingIndicator), findsNothing);
      when(
        () => gateway.ensureInitialized(sourceKey: 'b'),
      ).thenAnswer((_) async {});
      await tester.tap(find.text('Plugin b'));
      await tester.pumpAndSettle();
      expect(card, findsNothing);
      expect(active, 'b');
      expect(switches, 1);
      verify(() => gateway.activateSource('b')).called(2);
      verify(() => gateway.ensureInitialized(sourceKey: 'a')).called(1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('selecting the current source closes without reinitializing it', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(button);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Plugin a'));
    await tester.pumpAndSettle();
    expect(card, findsNothing);
    verifyNever(() => gateway.activateSource(any()));
    expect(switches, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'card scrolls through many sources in a short window with large text',
    (tester) async {
      tester.view.physicalSize = const Size(640, 350);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      sources = [
        for (var i = 0; i < 15; i++)
          SourceCatalogEntry(
            key: 'source_$i',
            name: 'Installed plugin $i',
            fileName: '$i.js',
          ),
      ];
      await pumpApp(tester, scale: 2);
      await tester.tap(button);
      await tester.pumpAndSettle();
      final bounds = tester.getRect(card);
      expect(bounds.left, greaterThanOrEqualTo(80));
      expect(bounds.bottom, lessThanOrEqualTo(350));
      final list = find.descendant(of: card, matching: find.byType(ListView));
      await tester.scrollUntilVisible(
        find.text('Installed plugin 14'),
        200,
        scrollable: find.descendant(
          of: list,
          matching: find.byType(Scrollable),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Installed plugin 14').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'no enabled plugins shows an empty state and a working close button',
    (tester) async {
      sources = [];
      await pumpApp(tester, locale: 'zh');
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.text('暂无已启用的插件，请先在设置中安装或启用插件。'), findsOneWidget);
      expect(find.byType(ListTile), findsNothing);
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(card, findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
