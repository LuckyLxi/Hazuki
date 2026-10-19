import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/shared/favorites/favorite_folders_button_morph.dart';

void main() {
  testWidgets(
    'button morph settles after arrival with distinct curved pulses',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final animation = AnimationController(
        vsync: tester,
        duration: const Duration(seconds: 1),
      );
      addTearDown(animation.dispose);
      const originRect = Rect.fromLTWH(319, 300, 48, 48);
      const surfaceKey = ValueKey('surface');
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: FavoriteFoldersButtonMorph(
                origin: const FavoriteFoldersMorphOrigin(
                  rect: originRect,
                  backgroundColor: Color(0xFFEEDDD5),
                  foregroundColor: Color(0xFF924F48),
                  icon: Icons.favorite_border,
                ),
                animation: animation,
                surfaceColor: Colors.white,
                outlineColor: Colors.grey,
                borderRadius: 32,
                shadowBlurRadius: 30,
                child: SizedBox(
                  key: surfaceKey,
                  width: 300,
                  height: 260,
                  child: TextButton(
                    onPressed: () => taps++,
                    child: const Text('Save'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final surface = find.byKey(surfaceKey);
      expect(tester.getRect(surface), originRect);
      animation.value = 0.5;
      await tester.pump();
      final openingRect = tester.getRect(surface);
      expect(openingRect.width, greaterThan(originRect.width));
      expect(openingRect.width, lessThan(300));
      await tester.tapAt(openingRect.center);
      expect(taps, 0);
      animation.value = 0.5999;
      await tester.pump();
      final beforeArrival = tester.getRect(surface).width;
      animation.value = 0.6;
      await tester.pump();
      final dialogRect = tester.getRect(surface);
      expect(dialogRect.size, const Size(300, 260));
      animation.value = 0.6001;
      await tester.pump();
      final incoming = dialogRect.width - beforeArrival;
      final outgoing = tester.getRect(surface).width - dialogRect.width;
      expect(incoming, greaterThan(0.01));
      expect(outgoing / incoming, closeTo(1, 0.02));
      animation.value = 0.6 + 0.4 / 3;
      await tester.pump();
      final overshootRect = tester.getRect(surface);
      expect(overshootRect.width, greaterThan(300));
      expect(overshootRect.width, closeTo(310.5, 0.01));
      expect(
        (overshootRect.center - dialogRect.center).distance,
        lessThan(0.001),
      );
      animation.value = 0.93;
      await tester.pump();
      expect(tester.getRect(surface).width, inExclusiveRange(300, 310.5));
      animation.value = 1;
      await tester.pump();
      expect(tester.getRect(surface).size, const Size(300, 260));
      await tester.tap(find.text('Save'));
      expect(taps, 1);
      animation.reverse();
      await tester.pump();
      expect(tester.getRect(surface), dialogRect);
      await tester.pump(const Duration(milliseconds: 500));
      final closingRect = tester.getRect(surface);
      expect(closingRect.width, inExclusiveRange(48, 300));
      await tester.pump(const Duration(microseconds: 99900));
      final beforeButton = tester.getRect(surface).width;
      await tester.pump(const Duration(microseconds: 100));
      expect(tester.getRect(surface).width, closeTo(48, 0.001));
      expect(
        (tester.getRect(surface).center - originRect.center).distance,
        lessThan(0.001),
      );
      final atButton = tester.getRect(surface).width;
      await tester.pump(const Duration(microseconds: 100));
      final afterButton = tester.getRect(surface).width;
      expect(atButton - beforeButton, lessThan(-0.001));
      expect(
        (afterButton - atButton) / (atButton - beforeButton),
        closeTo(1, 0.03),
      );
      await tester.pump(const Duration(microseconds: 132900));
      expect(tester.getRect(surface).width, closeTo(48 * 0.94, 0.001));
      expect(
        (tester.getRect(surface).center - originRect.center).distance,
        lessThan(0.001),
      );
      await tester.pump(const Duration(milliseconds: 197));
      expect(tester.getRect(surface).width, inExclusiveRange(48 * 0.94, 48));
      await tester.pump(const Duration(milliseconds: 70));
      expect(tester.getRect(surface).width, closeTo(48, 0.001));
      expect(tester.getRect(surface).height, closeTo(48, 0.001));
      expect(
        (tester.getRect(surface).center - originRect.center).distance,
        lessThan(0.001),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  for (final removedDuringClose in [false, true]) {
    testWidgets(
      'missing return button falls back safely, removed during close=$removedDuringClose',
      (tester) async {
        final animation = AnimationController(
          vsync: tester,
          duration: const Duration(seconds: 1),
          value: 1,
        );
        addTearDown(animation.dispose);
        const originRect = Rect.fromLTWH(320, 400, 32, 22);
        const returnRect = Rect.fromLTWH(80, 400, 32, 22);
        Rect? target = removedDuringClose ? returnRect : null;
        const surfaceKey = ValueKey('surface');
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: FavoriteFoldersButtonMorph(
                origin: FavoriteFoldersMorphOrigin(
                  rect: originRect,
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  icon: Icons.swap_horiz_rounded,
                  resolveReturnRect: () => target,
                ),
                animation: animation,
                surfaceColor: Colors.white,
                outlineColor: Colors.grey,
                borderRadius: 28,
                shadowBlurRadius: 22,
                child: const SizedBox(key: surfaceKey, width: 300, height: 260),
              ),
            ),
          ),
        );
        animation.reverse();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        target = null;
        await tester.pumpAndSettle();
        expect(
          tester.getRect(find.byKey(surfaceKey)),
          rectMoreOrLessEquals(
            removedDuringClose ? returnRect : originRect,
            epsilon: 0.001,
          ),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final openingValue in [0.5, 0.6 + 0.4 / 3]) {
    testWidgets(
      'closing morph at $openingValue preserves the painted geometry',
      (tester) async {
        final animation = AnimationController(
          vsync: tester,
          duration: const Duration(seconds: 1),
          value: openingValue,
        );
        addTearDown(animation.dispose);
        const sourceRect = Rect.fromLTWH(320, 400, 48, 48);
        const surfaceKey = ValueKey('surface');
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: FavoriteFoldersButtonMorph(
                origin: const FavoriteFoldersMorphOrigin(
                  rect: sourceRect,
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  icon: Icons.favorite_border,
                ),
                animation: animation,
                surfaceColor: Colors.white,
                outlineColor: Colors.grey,
                borderRadius: 32,
                shadowBlurRadius: 30,
                child: const SizedBox(key: surfaceKey, width: 300, height: 260),
              ),
            ),
          ),
        );
        final surface = find.byKey(surfaceKey);
        final beforeClose = tester.getRect(surface);
        animation.reverse();
        await tester.pump();
        expect(
          tester.getRect(surface),
          rectMoreOrLessEquals(beforeClose, epsilon: 0.000001),
        );
        await tester.pumpAndSettle();
        final finalRect = tester.getRect(surface);
        expect(finalRect.left, closeTo(sourceRect.left, 0.001));
        expect(finalRect.top, closeTo(sourceRect.top, 0.001));
        expect(finalRect.width, closeTo(sourceRect.width, 0.001));
        expect(finalRect.height, closeTo(sourceRect.height, 0.001));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
