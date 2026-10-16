import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/settings/view/other/chinese_conversion_menu.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/services/chinese_conversion_service.dart';

void main() {
  testWidgets('background stays blurred during opening and closing frames', (
    tester,
  ) async {
    final anchorKey = GlobalKey();
    final captureKey = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: captureKey,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: CustomPaint(
                painter: _StripedBackground(),
                child: Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: TextButton(
                      key: anchorKey,
                      onPressed: () {
                        showChineseConversionMenu(
                          context: context,
                          anchorKey: anchorKey,
                          selected: ChineseConversionMode.off,
                        );
                      },
                      child: const Text('Choose'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> expectBlurredFrame() async {
      final rect = tester.getRect(
        find.byKey(const ValueKey('chinese-conversion-menu-surface')),
      );
      final contrast = await tester.runAsync(() async {
        final boundary =
            captureKey.currentContext!.findRenderObject()
                as RenderRepaintBoundary;
        final snapshot = await boundary.toImage();
        try {
          final pixels = await snapshot.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          final y = rect.center.dy.round();
          final samples = [
            for (var x = rect.left.ceil() + 6; x < rect.left.ceil() + 22; x++)
              pixels!.getUint8((y * snapshot.width + x) * 4),
          ]..sort();
          return samples.last - samples.first;
        } finally {
          snapshot.dispose();
        }
      });
      expect(
        contrast,
        lessThan(25),
        reason:
            'Backdrop blur should smooth the black/white stripes before the animation completes',
      );
    }

    await tester.tap(find.byKey(anchorKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await expectBlurredFrame();
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 500));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    await expectBlurredFrame();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  for (final (size, brightness, scale) in [
    (const Size(320, 640), Brightness.light, 1.0),
    (const Size(320, 640), Brightness.dark, 2.0),
    (const Size(740, 360), Brightness.dark, 2.0),
  ]) {
    testWidgets(
      'menu opens above a bottom button and fits $size at scale $scale',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final anchorKey = GlobalKey();
        ChineseConversionMode? selection;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Navigator(
              onGenerateRoute: (_) => MaterialPageRoute<void>(
                builder: (context) => Scaffold(
                  body: Align(
                    alignment: Alignment.bottomRight,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: TextButton(
                        key: anchorKey,
                        onPressed: () async {
                          selection = await showChineseConversionMenu(
                            context: context,
                            anchorKey: anchorKey,
                            selected: ChineseConversionMode.off,
                          );
                        },
                        child: const Text('Choose'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final buttonRect = tester.getRect(find.byKey(anchorKey));
        await tester.tap(find.byKey(anchorKey));
        await tester.pumpAndSettle();
        final surface = find.byKey(
          const ValueKey('chinese-conversion-menu-surface'),
        );
        final menuRect = tester.getRect(surface);
        expect(menuRect.bottom, closeTo(buttonRect.top - 8, 0.1));
        expect(menuRect.right, closeTo(buttonRect.right, 0.1));
        expect(menuRect.left, greaterThanOrEqualTo(12));
        expect(menuRect.top, greaterThanOrEqualTo(12));
        expect(menuRect.right, lessThanOrEqualTo(size.width - 12));
        final choice = find.byKey(
          const ValueKey('chinese-conversion-choice-simplified'),
        );
        await tester.ensureVisible(choice);
        await tester.tap(choice);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 80));
        expect(surface, findsOneWidget);
        expect(
          tester
              .widget<Opacity>(
                find.byKey(const ValueKey('chinese-conversion-menu-opacity')),
              )
              .opacity,
          inExclusiveRange(0, 1),
        );
        await tester.pumpAndSettle();
        expect(surface, findsNothing);
        expect(selection, ChineseConversionMode.simplified);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('dismissing while opening reverses without an opacity jump', (
    tester,
  ) async {
    final anchorKey = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Align(
              alignment: Alignment.topRight,
              child: TextButton(
                key: anchorKey,
                onPressed: () {
                  showChineseConversionMenu(
                    context: context,
                    anchorKey: anchorKey,
                    selected: ChineseConversionMode.off,
                  );
                },
                child: const Text('Choose'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(anchorKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final opacity = find.byKey(
      const ValueKey('chinese-conversion-menu-opacity'),
    );
    final before = tester.widget<Opacity>(opacity).opacity;
    await tester.tapAt(const Offset(10, 500));
    await tester.pump();
    expect(tester.widget<Opacity>(opacity).opacity, closeTo(before, 0.001));
    await tester.pump(const Duration(milliseconds: 20));
    expect(tester.widget<Opacity>(opacity).opacity, lessThan(before));
    await tester.pumpAndSettle();
    expect(opacity, findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _StripedBackground extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (var x = 0.0; x < size.width; x += 4) {
      paint.color = (x / 4).round().isEven ? Colors.black : Colors.white;
      canvas.drawRect(Rect.fromLTWH(x, 0, 4, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_StripedBackground oldDelegate) => false;
}
