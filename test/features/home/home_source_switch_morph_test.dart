import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:mocktail/mocktail.dart';

import 'package:hazuki/features/home/support/home_sidebar_models.dart';
import 'package:hazuki/features/home/view/home_drawer_profile_header.dart';
import 'package:hazuki/features/home/view/home_source_switch_pill_button.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/shared/favorites/favorite_folders_button_morph.dart';
import 'package:hazuki/shared/liquid_glass_support.dart';
import 'package:hazuki/shared/source_account/source_account_actions.dart';

class _Gateway extends Mock implements SourceSwitchGateway {}

void main() {
  for (final glassEnabled in [false, true]) {
    group('liquid glass enabled=$glassEnabled', () {
      _sourceSwitchMorphTests(glassEnabled);
    });
  }
}

void _sourceSwitchMorphTests(bool glassEnabled) {
  late _Gateway gateway;
  late StateSetter setHomeState;
  late BuildContext homeContext;
  late ValueNotifier<bool> dialogOpenState;
  late GlobalKey sourceSwitchButtonKey;
  var dialogOpen = false;
  var headerRevision = 0;
  var activeSource = 'a';
  var username = 'guest';
  var profileLoading = false;
  Future<void> Function()? onSourceSwitched;
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
    dialogOpenState = ValueNotifier(false);
    sourceSwitchButtonKey = GlobalKey();
    dialogOpen = false;
    headerRevision = 0;
    activeSource = 'a';
    username = 'guest';
    profileLoading = false;
    onSourceSwitched = null;
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

  tearDown(() => dialogOpenState.dispose());

  Future<void> pumpHome(
    WidgetTester tester, {
    bool disableAnimations = false,
    bool deferHeaderUpdates = false,
  }) async {
    await tester.runAsync(
      () => HazukiLiquidGlass.initialize(enabled: glassEnabled),
    );
    addTearDown(() => HazukiLiquidGlass.setEnabled(false));
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
                  child: _DeferredDrawerContent(
                    deferUpdates: deferHeaderUpdates,
                    child: HomeDrawerProfileHeader(
                      key: ValueKey(headerRevision),
                      profile: HomeSidebarProfileState(
                        isLogged: false,
                        profileLoading: profileLoading,
                        avatarUrl: '',
                        username: username,
                        autoCheckInEnabled: false,
                        showCheckInActions: false,
                        checkInBusy: false,
                        checkedInToday: false,
                      ),
                      actions: HomeSidebarActions(
                        sourceSwitchButtonKey: sourceSwitchButtonKey,
                        sourceSwitchDialogOpen: dialogOpen,
                        sourceSwitchDialogOpenListenable: dialogOpenState,
                        onSwitchSourceWithMorph: (origin) async {
                          if (dialogOpen) return;
                          dialogOpenState.value = true;
                          setState(() => dialogOpen = true);
                          var buttonRestored = false;
                          void restoreButton() {
                            if (buttonRestored) return;
                            buttonRestored = true;
                            if (context.mounted) {
                              dialogOpenState.value = false;
                              setState(() => dialogOpen = false);
                            }
                          }

                          try {
                            await showHomeSourceSwitchDialog(
                              context,
                              sourceService: gateway,
                              morphOrigin: origin,
                              onSourceSwitched: () async {
                                await onSourceSwitched?.call();
                              },
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
      final glassSurface = find.byKey(
        const ValueKey('home-source-switch-liquid-glass-surface'),
      );
      expect(glassSurface, glassEnabled ? findsOneWidget : findsNothing);
      if (glassEnabled) {
        final container = tester.widget<GlassContainer>(glassSurface);
        expect(container.quality, HazukiLiquidGlass.navigationQuality);
        expect(
          container.settings,
          HazukiLiquidGlass.readerSettings(tester.element(glassSurface)),
        );
        expect(tester.getRect(glassSurface), origin);
        expect(
          find.ancestor(of: glassSurface, matching: find.byType(Opacity)),
          findsNothing,
        );
      }
      expect(
        tester.widget<FavoriteFoldersButtonMorph>(morph).origin.iconSize,
        16,
      );

      await tester.pump(const Duration(milliseconds: 168));
      expect(surfaceRect(tester).width, inExclusiveRange(32, 340));
      if (glassEnabled) {
        expect(tester.getRect(glassSurface), surfaceRect(tester));
      }
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

  testWidgets('open picker and pill follow the glass setting immediately', (
    tester,
  ) async {
    await pumpHome(tester);
    final glassButton = find.byKey(
      const ValueKey('home-source-switch-liquid-glass-button'),
    );
    final glassSurface = find.byKey(
      const ValueKey('home-source-switch-liquid-glass-surface'),
    );
    expect(glassButton, glassEnabled ? findsOneWidget : findsNothing);
    if (glassEnabled) {
      final container = tester.widget<GlassContainer>(glassButton);
      expect(container.quality, HazukiLiquidGlass.navigationQuality);
      expect(
        container.settings,
        HazukiLiquidGlass.navigationSettings(tester.element(glassButton)),
      );
    }
    await tester.tap(button);
    await tester.pumpAndSettle();
    final animation = tester
        .widget<FavoriteFoldersButtonMorph>(morph)
        .animation;
    final expanded = surfaceRect(tester);
    for (final enabled in [!glassEnabled, glassEnabled]) {
      await tester.runAsync(() => HazukiLiquidGlass.setEnabled(enabled));
      await tester.pumpAndSettle();
      expect(glassButton, enabled ? findsOneWidget : findsNothing);
      expect(glassSurface, enabled ? findsOneWidget : findsNothing);
      expect(
        tester.widget<FavoriteFoldersButtonMorph>(morph).animation,
        animation,
      );
      expect(surfaceRect(tester), expanded);
      expect(find.text('Source b').hitTestable(), findsOneWidget);
      expect(buttonOpacity(tester), 0);
    }
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(buttonOpacity(tester), 1);
    expect(tester.takeException(), isNull);
  });

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

  testWidgets('deferred drawer rebuild does not leave a blank closing frame', (
    tester,
  ) async {
    await pumpHome(tester, deferHeaderUpdates: true);
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
    // The header widget still carries the previous frame's dialogOpen value.
    // The pill must already be visible when the dialog route disappears.
    expect(buttonOpacity(tester), 1);
    await tester.pumpAndSettle();
    expect(buttonOpacity(tester), 1);
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

  for (final deferHeaderUpdates in [false, true]) {
    testWidgets(
      'switch returns to the new username with deferred header=$deferHeaderUpdates',
      (tester) async {
        await pumpHome(tester, deferHeaderUpdates: deferHeaderUpdates);
        final oldOrigin = tester.getRect(button);
        final initialized = Completer<void>();
        when(() => gateway.activateSource('b')).thenAnswer((_) async {
          activeSource = 'b';
          setHomeState(() {
            profileLoading = true;
            headerRevision++;
          });
        });
        when(
          () => gateway.ensureInitialized(sourceKey: 'b'),
        ).thenAnswer((_) => initialized.future);
        onSourceSwitched = () async {
          setHomeState(() {
            profileLoading = false;
            username = deferHeaderUpdates ? 'A much longer account name' : 'x';
            headerRevision++;
          });
        };
        await tester.tap(button);
        await tester.pumpAndSettle();
        final animation = tester
            .widget<FavoriteFoldersButtonMorph>(morph)
            .animation;
        await tester.tap(find.text('Source b'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(profileLoading, isTrue);
        initialized.complete();
        for (var frame = 0; frame < 8; frame++) {
          await tester.pump();
          if (animation.status == AnimationStatus.reverse) break;
        }
        expect(animation.status, AnimationStatus.reverse);
        await tester.pump();
        final target = tester.getRect(button);
        expect((target.left - oldOrigin.left).abs(), greaterThan(20));
        expect(buttonOpacity(tester), 0);
        // Keep the success prompt's staged entrance on separate frames.
        await tester.pump(const Duration(milliseconds: 70));
        await tester.pump(const Duration(milliseconds: 90));
        await tester.pump(const Duration(milliseconds: 40));
        await tester.pump(const Duration(milliseconds: 359));
        expect(
          surfaceRect(tester),
          rectMoreOrLessEquals(target, epsilon: 0.01),
        );
        expect(buttonOpacity(tester), 0);
        await tester.pump(const Duration(milliseconds: 2));
        expect(buttonOpacity(tester), 1);
        expect(tester.getRect(button), target);
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final elapsed in [200, 450]) {
    testWidgets(
      'username changes at ${elapsed}ms of closing keep the morph continuous',
      (tester) async {
        await pumpHome(tester);
        await tester.tap(button);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancel'));
        await tester.pump();
        await tester.pump(Duration(milliseconds: elapsed));
        final beforeUpdate = surfaceRect(tester);
        setHomeState(() {
          username = 'A much longer account name';
          headerRevision++;
        });
        await tester.pump();
        expect(
          surfaceRect(tester),
          rectMoreOrLessEquals(beforeUpdate, epsilon: 0.001),
        );
        final target = tester.getRect(button);
        await tester.pump(Duration(milliseconds: 559 - elapsed));
        expect(
          surfaceRect(tester),
          rectMoreOrLessEquals(target, epsilon: 0.01),
        );
        await tester.pump(const Duration(milliseconds: 2));
        expect(buttonOpacity(tester), 1);
        expect(tester.getRect(button), target);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }

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

/// Mirrors the profile drawer's post-frame forwarding of new header widgets.
class _DeferredDrawerContent extends StatefulWidget {
  const _DeferredDrawerContent({
    required this.deferUpdates,
    required this.child,
  });

  final bool deferUpdates;
  final Widget child;

  @override
  State<_DeferredDrawerContent> createState() => _DeferredDrawerContentState();
}

class _DeferredDrawerContentState extends State<_DeferredDrawerContent> {
  late Widget _visibleChild = widget.child;

  @override
  void didUpdateWidget(covariant _DeferredDrawerContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.deferUpdates) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _visibleChild = widget.child);
      });
    } else {
      _visibleChild = widget.child;
    }
  }

  @override
  Widget build(BuildContext context) => _visibleChild;
}
