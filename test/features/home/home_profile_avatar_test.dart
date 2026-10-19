import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/home/view/home_profile_avatar.dart';
import 'package:hazuki/services/source/gateways/source_image_gateways.dart';
import 'package:hazuki/widgets/widgets.dart';

void main() {
  setUp(clearHazukiWidgetImageMemoryForTesting);
  Widget wrap(Widget child) {
    return MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );
  }

  testWidgets('shows guest avatar when not loading and avatar url is empty', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(const HomeProfileAvatar(avatarUrl: '', loading: false, size: 48)),
    );

    expect(find.byIcon(Icons.person_outline), findsOneWidget);
    expect(find.byType(HazukiShimmerLoading), findsNothing);
  });

  testWidgets('shows loading placeholder while profile is loading', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(const HomeProfileAvatar(avatarUrl: '', loading: true, size: 48)),
    );

    expect(find.byType(HazukiShimmerLoading), findsOneWidget);
    expect(find.byIcon(Icons.person_outline), findsNothing);
  });

  for (final (borderRadius, animateOnLoad) in [
    (null, false),
    (BorderRadius.circular(16), false),
    (null, true),
  ]) {
    testWidgets(
      'retries transient avatar failure ($borderRadius, $animateOnLoad)',
      (tester) async {
        final gateway = _Images(failures: 1);
        await tester.pumpWidget(
          SourceImageGatewayScope(
            gateway: gateway,
            child: wrap(
              HomeProfileAvatar(
                avatarUrl: 'https://example/avatar',
                loading: false,
                size: 48,
                borderRadius: borderRadius,
                animateOnLoad: animateOnLoad,
              ),
            ),
          ),
        );
        await tester.pump();
        expect(gateway.downloads, 1);
        await tester.pump(const Duration(seconds: 1));
        await tester.pump();
        expect(gateway.downloads, 2);
        await tester.runAsync(
          () => precacheImage(
            MemoryImage(gateway.bytes),
            tester.element(find.byType(HomeProfileAvatar)),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(HazukiShimmerLoading), findsNothing);
      },
    );
  }

  testWidgets('stops retrying after two additional attempts', (tester) async {
    final gateway = _Images(failures: 100);
    await tester.pumpWidget(
      SourceImageGatewayScope(
        gateway: gateway,
        child: wrap(
          const HomeProfileAvatar(
            avatarUrl: 'https://example/avatar',
            loading: false,
            size: 48,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    await tester.pump(const Duration(seconds: 30));
    expect(gateway.downloads, 3);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('disposal cancels a scheduled avatar retry', (tester) async {
    final gateway = _Images(failures: 1);
    await tester.pumpWidget(
      SourceImageGatewayScope(
        gateway: gateway,
        child: wrap(
          const HomeProfileAvatar(
            avatarUrl: 'https://example/avatar',
            loading: false,
            size: 48,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
    expect(gateway.downloads, 1);
  });

  testWidgets('drawer Hero keeps the decoded avatar visible through landing', (
    tester,
  ) async {
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawColor(const Color(0xFFFF0000), BlendMode.src);
    final picture = recorder.endRecording();
    final bytes = await tester.runAsync(() async {
      final image = await picture.toImage(2, 2);
      try {
        return (await image.toByteData(
          format: ui.ImageByteFormat.png,
        ))!.buffer.asUint8List();
      } finally {
        image.dispose();
        picture.dispose();
      }
    });
    final gateway = _Images(failures: 0, imageBytes: bytes!);
    final rootKey = GlobalKey();
    const sourceKey = ValueKey('source-avatar');
    const drawerKey = ValueKey('drawer-avatar');
    await tester.pumpWidget(
      SourceImageGatewayScope(
        gateway: gateway,
        child: RepaintBoundary(
          key: rootKey,
          child: wrap(
            const HomeProfileAvatar(
              key: sourceKey,
              avatarUrl: 'https://example/avatar',
              loading: false,
              size: 38,
              heroEnabled: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.runAsync(
      () => precacheImage(
        MemoryImage(gateway.bytes),
        tester.element(find.byKey(sourceKey)),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> expectRedAvatar(Finder finder) async {
      final center = tester.getCenter(finder);
      final boundary =
          rootKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final pixel = await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        try {
          final pixels = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          final offset =
              (center.dy.floor() * image.width + center.dx.floor()) * 4;
          return List.generate(
            4,
            (channel) => pixels.getUint8(offset + channel),
          );
        } finally {
          image.dispose();
        }
      });
      expect(pixel, [255, 0, 0, 255]);
    }

    final flightImage = find.byWidgetPredicate(
      (widget) =>
          widget is Image &&
          find
              .ancestor(of: find.byWidget(widget), matching: find.byType(Hero))
              .evaluate()
              .isEmpty,
    );
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    await expectRedAvatar(find.byKey(sourceKey));
    // Repeat opening and closing: a warm-cache hit must not restart the reveal
    // either in the shuttle or when handing the image back to either route.
    for (var attempt = 0; attempt < 2; attempt++) {
      navigator.push(
        PageRouteBuilder<void>(
          opaque: false,
          transitionDuration: const Duration(milliseconds: 210),
          reverseTransitionDuration: const Duration(milliseconds: 160),
          pageBuilder: (_, _, _) => const Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: 304,
              child: Scaffold(
                body: Align(
                  alignment: Alignment.topLeft,
                  child: HomeProfileAvatar(
                    key: drawerKey,
                    avatarUrl: 'https://example/avatar',
                    loading: false,
                    size: 72,
                    heroEnabled: true,
                    animateOnLoad: true,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final drawerImage = find.descendant(
        of: find.byKey(drawerKey, skipOffstage: false),
        matching: find.byType(HazukiCachedImage, skipOffstage: false),
      );
      final imageState = tester.state(drawerImage);
      expect(
        tester.widget<HazukiCachedImage>(drawerImage).animateOnCacheHit,
        isFalse,
      );
      for (final elapsed in [16, 64, 100]) {
        await tester.pump(Duration(milliseconds: elapsed));
        expect(tester.state(drawerImage), same(imageState));
        expect(flightImage, findsOneWidget);
        await expectRedAvatar(flightImage);
      }
      await tester.pump(const Duration(milliseconds: 40));
      await tester.pump();
      expect(tester.state(drawerImage), same(imageState));
      await expectRedAvatar(find.byKey(drawerKey));
      await tester.pumpAndSettle();
      navigator.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      await expectRedAvatar(flightImage);
      await tester.pump(const Duration(milliseconds: 64));
      await expectRedAvatar(flightImage);
      await tester.pumpAndSettle();
      await expectRedAvatar(find.byKey(sourceKey));
    }
    expect(gateway.downloads, 1);
    expect(tester.takeException(), isNull);
  });
}

class _Images implements SourceImageGateway {
  _Images({required this.failures, Uint8List? imageBytes})
    : bytes =
          imageBytes ??
          base64Decode(
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
          );

  final int failures;
  int downloads = 0;
  final Uint8List bytes;

  @override
  String get activeSourceKey => 'source';

  @override
  Uint8List? peekImageBytesFromMemory(String url, {String sourceKey = ''}) =>
      null;

  @override
  Future<Uint8List> downloadImageBytes(
    String url, {
    String comicId = '',
    String epId = '',
    bool keepInMemory = false,
    bool useDiskCache = true,
    bool priority = false,
    String sourceKey = '',
  }) async {
    if (++downloads <= failures) throw StateError('offline');
    return bytes;
  }
}
