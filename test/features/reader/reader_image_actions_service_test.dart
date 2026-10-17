import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/reader/support/reader_image_actions_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('hazuki.comics/media');
  const service = ReaderImageActionsService();
  final bytes = Uint8List.fromList([1, 2, 3]);
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return call.method == 'saveImage' ? 'content://gallery/image' : null;
        });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('share and copy send image data instead of URL text', () async {
    await service.shareImage(bytes, 'png');
    await service.copyImage(bytes, 'png');
    expect(calls.map((call) => call.method), ['shareImage', 'copyImage']);
    for (final call in calls) {
      expect(call.arguments, {'bytes': bytes, 'extension': 'png'});
    }
  });

  test('Android saving uses the system gallery and returns its URI', () async {
    expect(
      await service.saveImage(bytes, 'png', 'page.png'),
      'content://gallery/image',
    );
    expect(calls.single.method, 'saveImage');
    expect(calls.single.arguments, {
      'bytes': bytes,
      'extension': 'png',
      'fileName': 'page.png',
    });
  });

  test(
    'Windows copying sends decoded RGBA pixels and image dimensions',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawRect(
        const ui.Rect.fromLTWH(0, 0, 1, 1),
        ui.Paint()..color = const ui.Color(0xffff0000),
      );
      canvas.drawRect(
        const ui.Rect.fromLTWH(0, 1, 1, 1),
        ui.Paint()..color = const ui.Color(0x8000ff00),
      );
      final picture = recorder.endRecording();
      final image = await picture.toImage(1, 2);
      late Uint8List encoded;
      try {
        final png = (await image.toByteData(format: ui.ImageByteFormat.png))!;
        encoded = png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes);
      } finally {
        image.dispose();
        picture.dispose();
      }

      await service.copyImage(encoded, 'png');

      expect(calls.single.method, 'copyImage');
      expect(calls.single.arguments, {
        'bytes': Uint8List.fromList([255, 0, 0, 255, 0, 255, 0, 128]),
        'width': 1,
        'height': 2,
      });
    },
  );

  test('Windows rejects invalid images before calling the clipboard', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    await expectLater(
      service.copyImage(bytes, 'png'),
      throwsA(isA<Exception>()),
    );
    expect(calls, isEmpty);
  });

  test('a missing gallery result cannot report a successful save', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => null);
    await expectLater(
      service.saveImage(bytes, 'png', 'page.png'),
      throwsStateError,
    );
  });
}
