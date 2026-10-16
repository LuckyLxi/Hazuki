import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:hazuki/features/home/support/home_sidebar_models.dart';
import 'package:hazuki/features/home/view/home_drawer_profile_header.dart';
import 'package:hazuki/features/home/view/home_source_switch_pill_button.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/shared/favorites/favorite_folders_button_morph.dart';
import 'package:hazuki/shared/source_account/source_account_actions.dart';

class _Gateway extends Mock implements SourceSwitchGateway {}

void main() {
  late _Gateway gateway;
  late StateSetter setHomeState;
  late BuildContext homeContext;
  var dialogOpen = false;
  var headerRevision = 0;
  var activeSource = 'a';
  final button = find.byType(HomeSourceSwitchPillButton);
  final morph = find.byType(FavoriteFoldersButtonMorph);

  double buttonOpacity(WidgetTester tester) => tester
      .widget<Opacity>(
        find.ancestor(of: button, matching: find.byType(Opacity)).first,
      )
      .opacity;

  Rect surfaceRect(WidgetTester tester) => tester.getRect(
    find.byWidget(tester.widget<FavoriteFoldersButtonMorph>(morph).child!),
  );

  setUp(() {
    dialogOpen = false;
    headerRevision = 0;
    activeSource = 'a';
    gateway = _Gateway();
    when(gateway.loadActiveSourcePreference).thenAnswer((_) async {});
    when(() => gateway.activeSourceKey).thenAnswer((_) => activeSource);
    when(() => gateway.allowedSources).thenReturn([
      for (final id in ['a', 'b'])
        SourceCatalogEntry(key: id, name: 'Source $id', fileName: '$id.js'),
    ]);
    when(() => gateway.hasLocalSourceFile('b')).thenAnswer((_) async => true);
    when(() => gateway.activateSource('b')).thenAnswer((_) async {
      activeSource = 'b';
      setHomeState(() => headerRevision++);
    });
    when(
      () => gateway.ensureInitialized(sourceKey: 'b'),
    ).thenAnswer((_) async {});
  });

  Future<void> pumpHome(
    WidgetTester tester, {
    bool disableAnimations = false,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: disableAnimations),
          child: child!,
        ),
        home: StatefulBuilder(
          builder: (context, setState) {
            homeContext = context;
            setHomeState = setState;
            return Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 304,
                  child: HomeDrawerProfileHeader(
                    key: ValueKey(headerRevision),
                    profile: const HomeSidebarProfileState(
                      isLogged: false,
                      profileLoading: false,
                      avatarUrl: '',
                      username: 'guest',
                      autoCheckInEnabled: false,
                      showCheckInActions: false,
                      checkInBusy: false,
                      checkedInToday: false,
                    ),
                    actions: HomeSidebarActions(
                      sourceSwitchDialogOpen: dialogOpen,
                      onSwitchSourceWithMorph: (origin) async {
                        if (dialogOpen) return;
                        setState(() => dialogOpen = true);
                        var buttonRestored = false;
                        void restoreButton() {
                          if (buttonRestored) return;
                          buttonRestored = true;
                          if (context.mounted) {
                            setState(() => dialogOpen = false);
                          }
                        }

                        try {
                          await showHomeSourceSwitchDialog(
                            context,
                            sourceService: gateway,
                            morphOrigin: origin,
                            onDialogClosed: restoreButton,
                          );
                        } finally {
                          restoreButton();
                        }
                      },
                    ),
                    activeSourceKey: activeSource,
                    backgroundColor: Theme.of(context).colorScheme.surface,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'drawer picker expands from its pill and returns before restoring it',
    (tester) async {
      await pumpHome(tester);
      final origin = tester.getRect(button);
      expect(origin.size, const Size(32, 22));
      await tester.tap(button);
      await tester.pump();
      expect(buttonOpacity(tester), 0);
      expect(surfaceRect(tester), origin);
      expect(
        tester.widget<FavoriteFoldersButtonMorph>(morph).origin.iconSize,
        16,
      );

      await tester.pump(const Duration(milliseconds: 168));
      expect(surfaceRect(tester).width, inExclusiveRange(32, 340));
      expect(find.text('Cancel').hitTestable(), findsNothing);
      await tester.pumpAndSettle();
      final expanded = surfaceRect(tester);
      expect(expanded.width, 310); // 390 minus the Dialog's horizontal insets.

      await tester.tap(find.text('Cancel'));
      await tester.pump();
      expect(buttonOpacity(tester), 0);
      expect(surfaceRect(tester), expanded);
      await tester.pump(const Duration(milliseconds: 280));
      expect(surfaceRect(tester).width, inExclusiveRange(32, expanded.width));
      expect(buttonOpacity(tester), 0);
      await tester.pumpAndSettle();
      expect(morph, findsNothing);
      expect(buttonOpacity(tester), 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('pill is visible in the frame the closing animation finishes', (
    tester,
  ) async {
    await pumpHome(tester);
    await tester.tap(button);
    await tester.pumpAndSettle();
    final animation = tester
        .widget<FavoriteFoldersButtonMorph>(morph)
        .animation;
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 559));
    expect(buttonOpacity(tester), 0);
    await tester.pump(const Duration(milliseconds: 2));
    expect(animation.status, AnimationStatus.dismissed);
    expect(buttonOpacity(tester), 1);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  for (final dismiss in ['barrier', 'back', 'early']) {
    testWidgets('drawer picker restores its pill after $dismiss dismissal', (
      tester,
    ) async {
      await pumpHome(tester);
      await tester.tap(button);
      await tester.pump();
      if (dismiss == 'early') {
        await tester.pump(const Duration(milliseconds: 100));
      } else {
        await tester.pumpAndSettle();
      }
      if (dismiss == 'barrier') {
        await tester.tapAt(const Offset(380, 800));
      } else {
        await Navigator.of(homeContext).maybePop();
      }
      await tester.pump();
      expect(buttonOpacity(tester), 0);
      await tester.pumpAndSettle();
      expect(morph, findsNothing);
      expect(buttonOpacity(tester), 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('switching keeps a rebuilt header hidden until automatic close', (
    tester,
  ) async {
    await pumpHome(tester);
    final initialized = Completer<void>();
    when(
      () => gateway.ensureInitialized(sourceKey: 'b'),
    ).thenAnswer((_) => initialized.future);
    await tester.tap(button);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Source b'));
    await tester.pump();
    expect(headerRevision, 1);
    expect(buttonOpacity(tester), 0);
    await tester.pump(const Duration(milliseconds: 400));
    initialized.complete();
    await tester.pump();
    // Advance through the success prompt's staged entrance separately.
    await tester.pump(const Duration(milliseconds: 70));
    await tester.pump(const Duration(milliseconds: 90));
    await tester.pump(const Duration(milliseconds: 40));
    expect(buttonOpacity(tester), 0);
    await tester.pumpAndSettle();
    expect(morph, findsNothing);
    expect(buttonOpacity(tester), 1);
    verify(() => gateway.activateSource('b')).called(1);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('drawer picker respects disabled animations', (tester) async {
    await pumpHome(tester, disableAnimations: true);
    await tester.tap(button);
    await tester.pumpAndSettle();
    final animation = tester
        .widget<FavoriteFoldersButtonMorph>(morph)
        .animation;
    expect(animation.status, AnimationStatus.completed);
    final route = ModalRoute.of(tester.element(morph))!;
    expect(route.transitionDuration, Duration.zero);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(buttonOpacity(tester), 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed switch restores the picker and its closing animation', (
    tester,
  ) async {
    await pumpHome(tester);
    final initialized = Completer<void>();
    when(
      () => gateway.ensureInitialized(sourceKey: 'b'),
    ).thenAnswer((_) => initialized.future);
    when(() => gateway.ensureInitialized(sourceKey: 'a')).thenAnswer((_) async {
      activeSource = 'a';
    });
    await tester.tap(button);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Source b'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await Navigator.of(homeContext).maybePop();
    await tester.pump();
    expect(morph, findsOneWidget);
    expect(buttonOpacity(tester), 0);
    initialized.completeError(StateError('initialization failed'));
    await tester.pumpAndSettle();
    expect(find.textContaining('initialization failed'), findsOneWidget);
    expect(find.text('Source b').hitTestable(), findsOneWidget);
    verify(() => gateway.ensureInitialized(sourceKey: 'a')).called(1);
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    expect(buttonOpacity(tester), 0);
    await tester.pumpAndSettle();
    expect(morph, findsNothing);
    expect(buttonOpacity(tester), 1);
    expect(tester.takeException(), isNull);
  });
}
