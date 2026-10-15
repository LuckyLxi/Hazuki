import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/home/view/home_profile_avatar.dart';
import 'package:hazuki/services/source/gateways/source_image_gateways.dart';
import 'package:hazuki/shared/navigation/snapshotting_page_route.dart';
import 'package:hazuki/shared/ui_flags.dart';
import 'package:hazuki/widgets/cached_image_widgets.dart';
import 'package:hazuki/widgets/source_image_gateway_scope.dart';

void main() {
  setUp(clearHazukiWidgetImageMemoryForTesting);

  testWidgets('home avatar stays painted when returning after cache eviction', (
    tester,
  ) async {
    final gateway = _AvatarGateway();
    final navigatorKey = GlobalKey<NavigatorState>();
    final boundaryKey = GlobalKey();
    final cache = PaintingBinding.instance.imageCache;
    final originalMaximumSize = cache.maximumSize;
    addTearDown(() => cache.maximumSize = originalMaximumSize);

    await tester.pumpWidget(
      SourceImageGatewayScope(
        gateway: gateway,
        child: MaterialApp(
          navigatorKey: navigatorKey,
          theme: ThemeData(platform: TargetPlatform.android),
          home: Scaffold(
            body: Center(
              child: RepaintBoundary(
                key: boundaryKey,
                child: const HomeProfileAvatar(
                  avatarUrl: 'avatar',
                  loading: false,
                  size: 38,
                  heroEnabled: true,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await _finishDecoding(tester, gateway.latestBytes);
    final expectedPixel = await _centerPixel(tester, boundaryKey);
    expect(expectedPixel, [0, 0, 0, 255]);
    final avatarState = tester.state(find.byType(HazukiCachedCircleAvatar));

    // Reproduce the avatar being evicted by the home page's larger images.
    cache.maximumSize = 0;
    final route =
        buildSnapshottingPageRoute<void>(
              allowSnapshotting: false,
              builder: (_) => const Scaffold(body: Text('detail')),
            )
            as PageRoute<void>;
    navigatorKey.currentState!.push(route);
    await tester.pumpAndSettle();
    navigatorKey.currentState!.pop();
    await tester.pump();
    const frame = Duration(milliseconds: 16);
    await tester.pump(route.reverseTransitionDuration - frame * 2);

    for (var index = 0; index < 6; index++) {
      await tester.pump(frame);
      expect(
        tester.state(find.byType(HazukiCachedCircleAvatar)),
        same(avatarState),
      );
      expect(
        await _centerPixel(tester, boundaryKey),
        expectedPixel,
        reason: 'The avatar must remain painted as the transition ends.',
      );
    }
    expect(gateway.downloads, 1);
  });

  testWidgets('releases decoded avatars when replaced, hidden, or disposed', (
    tester,
  ) async {
    final gateway = _AvatarGateway();
    final cache = PaintingBinding.instance.imageCache;
    final originalMaximumSize = cache.maximumSize;
    addTearDown(() {
      cache.maximumSize = originalMaximumSize;
      hazukiNoImageModeNotifier.value = false;
    });
    cache.maximumSize = 0;

    Future<MemoryImage> showAvatar(String url) async {
      await tester.pumpWidget(
        MaterialApp(
          home: HazukiCachedCircleAvatar(url: url, imageGateway: gateway),
        ),
      );
      await _finishDecoding(tester, gateway.latestBytes);
      return MemoryImage(gateway.latestBytes);
    }

    final firstImage = await showAvatar('first');
    expect(cache.statusForKey(firstImage).live, isTrue);
    final secondImage = await showAvatar('second');
    expect(cache.statusForKey(firstImage).live, isFalse);
    expect(cache.statusForKey(secondImage).live, isTrue);

    gateway.activeSourceKey = 'other';
    final otherSourceImage = await showAvatar('second');
    expect(cache.statusForKey(otherSourceImage).live, isTrue);
    // Finish any decode of the former image requested by the decoration tween.
    await _finishDecoding(tester, secondImage.bytes);

    hazukiNoImageModeNotifier.value = true;
    await tester.pumpAndSettle();
    // CircleAvatar can keep both sources during its decoration interpolation.
    // Removing that decoration must release both, including our extra listener.
    expect(cache.statusForKey(secondImage).live, isFalse);
    expect(cache.statusForKey(otherSourceImage).live, isFalse);

    hazukiNoImageModeNotifier.value = false;
    await _finishDecoding(tester, gateway.latestBytes);
    expect(cache.statusForKey(otherSourceImage).live, isTrue);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(cache.statusForKey(otherSourceImage).live, isFalse);
  });
}

Future<void> _finishDecoding(WidgetTester tester, Uint8List bytes) async {
  await tester.pumpAndSettle();
  await tester.runAsync(
    () => precacheImage(
      MemoryImage(bytes),
      tester.element(find.byType(HazukiCachedCircleAvatar)),
    ),
  );
  await tester.pumpAndSettle();
}

Future<List<int>> _centerPixel(WidgetTester tester, GlobalKey key) async {
  final boundary =
      key.currentContext!.findRenderObject() as RenderRepaintBoundary;
  final image = (await tester.runAsync(boundary.toImage))!;
  try {
    final data = (await tester.runAsync(
      () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
    ))!;
    final offset = ((image.height ~/ 2) * image.width + image.width ~/ 2) * 4;
    return data.buffer.asUint8List().sublist(offset, offset + 4);
  } finally {
    image.dispose();
  }
}

class _AvatarGateway implements SourceImageGateway {
  @override
  String activeSourceKey = 'avatar-source';

  int downloads = 0;
  Uint8List latestBytes = Uint8List(0);

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
    downloads++;
    latestBytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    );
    return latestBytes;
  }
}
