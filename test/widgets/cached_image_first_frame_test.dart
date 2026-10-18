import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/widgets/cached_image_widgets.dart';

class _Images extends Fake implements SourceImageGateway {
  _Images(this.bytes);
  final Uint8List bytes;

  @override
  String get activeSourceKey => 'website';

  @override
  Uint8List? peekImageBytesFromMemory(String url, {String sourceKey = ''}) =>
      bytes;
}

void main() {
  setUp(clearHazukiWidgetImageMemoryForTesting);

  testWidgets('cached first frames respect disabled cache-hit animation', (
    tester,
  ) async {
    final bytes = Uint8List.fromList([7, 8, 9]);
    final decoded = Completer<ImageInfo>.sync();
    final cache = PaintingBinding.instance.imageCache;
    cache.putIfAbsent(
      MemoryImage(bytes),
      () => OneFrameImageStreamCompleter(decoded.future),
    );
    const placeholder = ValueKey('cache-hit-placeholder');
    await tester.pumpWidget(
      MaterialApp(
        home: HazukiCachedImage(
          url: 'https://example.com/cached.png',
          imageGateway: _Images(bytes),
          width: 200,
          height: 100,
          waitForFirstFrame: true,
          animateOnLoad: true,
          animateOnCacheHit: false,
          useShimmerLoading: false,
          loading: const ColoredBox(key: placeholder, color: Colors.grey),
        ),
      ),
    );
    expect(find.byKey(placeholder), findsOneWidget);
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawColor(Colors.blue, BlendMode.src);
    final picture = recorder.endRecording();
    decoded.complete(ImageInfo(image: picture.toImageSync(2, 2)));
    picture.dispose();
    await tester.pump();
    expect(find.byKey(placeholder), findsNothing);
    expect(find.byType(AnimatedOpacity), findsNothing);
    expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
    await tester.pumpWidget(const SizedBox());
    cache.clear();
    cache.clearLiveImages();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'presentation controller retains and releases its decoded frame',
    (tester) async {
      const url = 'https://example.com/retained.png';
      final bytes = Uint8List.fromList([10, 11, 12]);
      final controller = HazukiCachedImageController();
      addTearDown(controller.dispose);
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawColor(Colors.blue, BlendMode.src);
      final picture = recorder.endRecording();
      final decoded = Completer<ImageInfo>.sync();
      final cache = PaintingBinding.instance.imageCache;
      cache.putIfAbsent(
        MemoryImage(bytes),
        () => OneFrameImageStreamCompleter(decoded.future),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: HazukiCachedImage(
            url: url,
            sourceKey: 'website',
            imageGateway: _Images(bytes),
            controller: controller,
            waitForFirstFrame: true,
          ),
        ),
      );
      decoded.complete(ImageInfo(image: picture.toImageSync(2, 2)));
      picture.dispose();
      await tester.pumpAndSettle();
      final frame = controller.frameFor(url, sourceKey: 'website');
      expect(frame, isNotNull);
      expect(controller.bytesFor(url, sourceKey: 'website'), same(bytes));
      expect(controller.bytesFor(url, sourceKey: 'other'), isNull);
      await tester.pumpWidget(const SizedBox());
      clearHazukiWidgetImageMemoryForTesting();
      cache.clear();
      cache.clearLiveImages();
      expect(controller.frameFor(url, sourceKey: 'website'), same(frame));
      final retainedClone = frame!.clone();
      retainedClone.dispose();
      controller.dispose();
      expect(controller.frameFor(url, sourceKey: 'website'), isNull);
      expect(controller.bytesFor(url, sourceKey: 'website'), isNull);
      expect(tester.takeException(), isNull);
    },
  );

  for (final failDecoding in [false, true]) {
    testWidgets(
      failDecoding
          ? 'decode failures keep the configured fallback visible'
          : 'placeholder remains after bytes arrive until a decoded frame appears',
      (tester) async {
        final bytes = Uint8List.fromList([1, 2, 3]);
        final decoded = Completer<ImageInfo>.sync();
        final cache = PaintingBinding.instance.imageCache;
        cache.putIfAbsent(
          MemoryImage(bytes),
          () => OneFrameImageStreamCompleter(decoded.future),
        );
        const placeholderKey = ValueKey('first-frame-placeholder');
        const errorKey = ValueKey('first-frame-error');
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: HazukiCachedImage(
                url: 'https://example.com/banner.png',
                imageGateway: _Images(bytes),
                width: 200,
                height: 100,
                waitForFirstFrame: true,
                animateOnLoad: true,
                animateOnCacheHit: true,
                useShimmerLoading: false,
                loading: const ColoredBox(
                  key: placeholderKey,
                  color: Colors.grey,
                ),
                error: const ColoredBox(key: errorKey, color: Colors.grey),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(seconds: 1));
        // Bytes have been supplied from memory, but decoding is still pending.
        expect(find.byKey(placeholderKey), findsOneWidget);
        expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNull);
        expect(
          tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
          0,
        );

        if (failDecoding) {
          decoded.completeError(StateError('invalid image'));
          await tester.pumpAndSettle();
          expect(find.byKey(errorKey), findsOneWidget);
          expect(find.byType(RawImage), findsNothing);
        } else {
          final recorder = ui.PictureRecorder();
          Canvas(recorder).drawColor(Colors.blue, BlendMode.src);
          final picture = recorder.endRecording();
          final image = picture.toImageSync(2, 2);
          picture.dispose();
          decoded.complete(ImageInfo(image: image));
          await tester.pump();
          expect(find.byKey(placeholderKey), findsOneWidget);
          expect(
            tester.widget<RawImage>(find.byType(RawImage)).image,
            isNotNull,
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 130));
          expect(find.byKey(placeholderKey), findsOneWidget);
          final fade = tester.state<ImplicitlyAnimatedWidgetState>(
            find.byType(AnimatedOpacity),
          );
          expect(fade.animation.value, allOf(greaterThan(0), lessThan(1)));
          await tester.pumpAndSettle();
          expect(find.byKey(placeholderKey), findsNothing);
          expect(find.byType(RawImage), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        cache.clear();
        cache.clearLiveImages();
      },
    );
  }
}
