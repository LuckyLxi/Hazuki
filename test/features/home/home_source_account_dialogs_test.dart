import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/services/source/gateways/source_image_gateways.dart';
import 'package:hazuki/shared/liquid_glass_support.dart';
import 'package:hazuki/shared/source_account/source_account_dialogs.dart';
import 'package:hazuki/widgets/source_image_gateway_scope.dart';

void main() {
  testWidgets('dialog blur covers the screen throughout open and close', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = FakeViewPadding(top: 24, bottom: 20);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showHomeAnimatedDialog<void>(
                context,
                child: const AlertDialog(title: Text('Dialog')),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    void expectFullScreenBlur({required double progress}) {
      final filter = tester.renderObject<RenderBackdropFilter>(
        find.byType(BackdropFilter),
      );
      final screenBounds = MatrixUtils.transformRect(
        filter.getTransformTo(null),
        Offset.zero & filter.size,
      );
      expect(screenBounds, const Rect.fromLTWH(0, 0, 412, 915));
      _expectNoOpacityLayerAbove(filter);
      final sigma = 8 * progress;
      expect(
        filter.filterConfig.filter,
        ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
      );
    }

    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 65));
    expectFullScreenBlur(progress: Curves.easeOutCubic.transform(0.25));
    await tester.pump(const Duration(milliseconds: 65));
    expectFullScreenBlur(progress: Curves.easeOutCubic.transform(0.5));
    await tester.pumpAndSettle();
    expectFullScreenBlur(progress: 1);

    await tester.tapAt(const Offset(4, 100));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 65));
    expectFullScreenBlur(progress: Curves.easeInCubic.transform(0.75));
    await tester.pump(const Duration(milliseconds: 65));
    expectFullScreenBlur(progress: Curves.easeInCubic.transform(0.5));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(BackdropFilter), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile glass card stays clipped while closing', (tester) async {
    await tester.runAsync(HazukiLiquidGlass.initialize);

    await _pumpProfileHost(tester);

    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 65));

    void expectGlassTransition(double progress) {
      final card = find.byKey(const ValueKey('home-profile-liquid-glass-card'));
      _expectNoOpacityLayerAbove(tester.renderObject(card));
      final container = tester.widget<GlassContainer>(card);
      expect(container.quality, HazukiLiquidGlass.navigationQuality);
      expect(
        container.settings,
        HazukiLiquidGlass.readerSettings(
          tester.element(card),
        ).copyWith(visibility: progress),
      );
      expect(container.settings!.visibility, closeTo(progress, 0.00001));
      final glass = tester.widget<LightweightLiquidGlass>(
        find.descendant(
          of: card,
          matching: find.byType(LightweightLiquidGlass),
        ),
      );
      expect(glass.settings!.visibility, closeTo(progress, 0.00001));
    }

    expectGlassTransition(Curves.easeOutCubic.transform(0.25));
    await tester.pumpAndSettle();
    expectGlassTransition(1);

    const cardKey = ValueKey('home-profile-liquid-glass-card');
    final card = find.byKey(cardKey);
    expect(card, findsOneWidget);
    // Premium glass must sample the full-screen backdrop directly. Nesting it
    // in the dialog blur introduces a different compositor coordinate space.
    expect(
      find.ancestor(of: card, matching: find.byType(BackdropFilter)),
      findsNothing,
    );
    final cardBounds = tester.getRect(card);
    final logoutBounds = tester.getRect(find.byType(ListTile));
    expect(cardBounds.contains(logoutBounds.topLeft), isTrue);
    expect(cardBounds.contains(logoutBounds.bottomRight), isTrue);
    expect(
      find.ancestor(of: card, matching: find.byType(ClipRSuperellipse)),
      findsOneWidget,
    );

    await tester.tapAt(const Offset(4, 4));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expectGlassTransition(Curves.easeInCubic.transform(1 - 80 / 260));

    expect(card, findsOneWidget);
    expect(
      find.ancestor(of: card, matching: find.byType(ClipRSuperellipse)),
      findsOneWidget,
    );
    await tester.pumpAndSettle();
    expect(card, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('open profile follows the glass setting without closing', (
    tester,
  ) async {
    await tester.runAsync(HazukiLiquidGlass.initialize);
    addTearDown(() => HazukiLiquidGlass.setEnabled(false));
    await _pumpProfileHost(tester);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final glass = find.byKey(const ValueKey('home-profile-liquid-glass-card'));
    final frosted = find.byKey(
      const ValueKey('home-profile-frosted-glass-card'),
    );
    final originalBounds = tester.getRect(glass);
    for (final enabled in [false, true]) {
      await tester.runAsync(() => HazukiLiquidGlass.setEnabled(enabled));
      await tester.pumpAndSettle();
      expect(glass, enabled ? findsOneWidget : findsNothing);
      expect(frosted, enabled ? findsNothing : findsOneWidget);
      final bounds = tester.getRect(enabled ? glass : frosted);
      expect(bounds.center, originalBounds.center);
      expect(bounds.width, originalBounds.width);
      expect(find.text('Hazuki'), findsOneWidget);
    }
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
    expect(find.byType(HomeProfileCardContent), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('frosted profile fades without isolating its backdrop', (
    tester,
  ) async {
    await HazukiLiquidGlass.setEnabled(false);
    addTearDown(() => HazukiLiquidGlass.setEnabled(true));
    await _pumpProfileHost(tester);
    await tester.tap(find.text('Open'));
    await tester.pump();

    void expectFrostedTransition(double progress) {
      final card = find.byKey(
        const ValueKey('home-profile-frosted-glass-card'),
      );
      final filter = tester.renderObject<RenderBackdropFilter>(
        find.descendant(of: card, matching: find.byType(BackdropFilter)),
      );
      _expectNoOpacityLayerAbove(filter);
      expect(
        filter.filterConfig.filter,
        ui.ImageFilter.blur(sigmaX: 24 * progress, sigmaY: 24 * progress),
      );
    }

    await tester.pump(const Duration(milliseconds: 65));
    expectFrostedTransition(Curves.easeOutCubic.transform(0.25));
    await tester.pumpAndSettle();
    expectFrostedTransition(1);
    await tester.tapAt(const Offset(4, 4));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 65));
    expectFrostedTransition(Curves.easeInCubic.transform(0.75));
    await tester.pumpAndSettle();
    expect(find.byType(HomeProfileCardContent), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpProfileHost(WidgetTester tester) {
  return tester.pumpWidget(
    SourceImageGatewayScope(
      gateway: const _EmptyImageGateway(),
      child: HazukiLiquidGlass.wrap(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showHomeAvatarCard(
                  context,
                  avatarUrl: '',
                  username: 'Hazuki',
                  firstUseText: 'First used today',
                  onLogoutTap: () {},
                  onRequestSaveAvatar: () async {},
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void _expectNoOpacityLayerAbove(RenderObject target) {
  RenderObject? ancestor = target.parent;
  while (ancestor != null) {
    if (ancestor is RenderOpacity) {
      expect(ancestor.opacity, 1);
    } else if (ancestor is RenderAnimatedOpacity) {
      expect(ancestor.opacity.value, 1);
    }
    ancestor = ancestor.parent;
  }
}

class _EmptyImageGateway implements SourceImageGateway {
  const _EmptyImageGateway();

  @override
  String get activeSourceKey => 'test';

  @override
  Uint8List? peekImageBytesFromMemory(String url, {String sourceKey = ''}) {
    return null;
  }

  @override
  Future<Uint8List> downloadImageBytes(
    String url, {
    String comicId = '',
    String epId = '',
    bool keepInMemory = false,
    bool useDiskCache = true,
    bool priority = false,
    String sourceKey = '',
  }) {
    throw StateError('No image download expected in this test.');
  }
}
