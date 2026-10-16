import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hazuki/features/home/view/home_source_switch_pill_button.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/shared/favorites/favorite_folders_button_morph.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('morph keeps the pill border at both endpoints in $brightness', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 240);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final animation = AnimationController(
        vsync: tester,
        duration: const Duration(seconds: 1),
      );
      addTearDown(animation.dispose);
      final boundaryKey = GlobalKey();
      late FavoriteFoldersMorphOrigin origin;
      late StateSetter setSceneState;
      var showMorph = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: brightness),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: RepaintBoundary(
              key: boundaryKey,
              child: StatefulBuilder(
                builder: (context, setState) {
                  setSceneState = setState;
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      ColoredBox(color: Theme.of(context).colorScheme.surface),
                      if (showMorph)
                        Center(
                          child: FavoriteFoldersButtonMorph(
                            origin: origin,
                            animation: animation,
                            surfaceColor: Colors.white,
                            outlineColor: Colors.transparent,
                            borderRadius: 28,
                            shadowBlurRadius: 22,
                            child: const SizedBox(width: 200, height: 160),
                          ),
                        )
                      else
                        Positioned(
                          left: 96,
                          top: 96,
                          child: HomeSourceSwitchMorphButton(
                            dialogOpen: false,
                            onPressed: (value) async => origin = value,
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      Future<ByteData> pixels() async {
        final boundary =
            boundaryKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        return (await tester.runAsync(() async {
          final image = await boundary.toImage();
          try {
            return await image.toByteData(format: ui.ImageByteFormat.rawRgba);
          } finally {
            image.dispose();
          }
        }))!;
      }

      final buttonPixels = await pixels();
      await tester.tap(find.byType(HomeSourceSwitchPillButton));
      await tester.pumpAndSettle();
      setSceneState(() => showMorph = true);
      await tester.pump();

      Future<void> expectSameBorder(String phase) async {
        final morphPixels = await pixels();
        // The top straight edge is outside the icon and away from the corners.
        for (var x = 109; x <= 114; x++) {
          final offset = (96 * 320 + x) * 4;
          for (var channel = 0; channel < 4; channel++) {
            expect(
              morphPixels.getUint8(offset + channel),
              closeTo(buttonPixels.getUint8(offset + channel), 1),
              reason: '$phase border pixel at x=$x, channel=$channel',
            );
          }
        }
      }

      await expectSameBorder('opening');
      animation.value = 1;
      await tester.pump();
      animation.reverse();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await expectSameBorder('return arrival');
      await tester.pump(const Duration(milliseconds: 399));
      await expectSameBorder('last closing frame');
      await tester.pumpAndSettle();
      await expectSameBorder('closed');
      expect(tester.takeException(), isNull);
    });
  }
}
