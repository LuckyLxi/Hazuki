import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class ReaderImageActionsService {
  const ReaderImageActionsService();

  static const _channel = MethodChannel('hazuki.comics/media');

  Future<void> shareImage(Uint8List bytes, String extension) =>
      _sendImage('shareImage', bytes, extension);

  Future<void> copyImage(Uint8List bytes, String extension) async {
    if (defaultTargetPlatform != TargetPlatform.windows) {
      await _sendImage('copyImage', bytes, extension);
      return;
    }

    final codec = await ui.instantiateImageCodec(bytes);
    try {
      final frame = await codec.getNextFrame();
      final image = frame.image;
      try {
        final pixels = await image.toByteData(
          format: ui.ImageByteFormat.rawStraightRgba,
        );
        if (pixels == null) throw StateError('Unable to decode the image');
        await _channel.invokeMethod<void>('copyImage', {
          'bytes': pixels.buffer.asUint8List(
            pixels.offsetInBytes,
            pixels.lengthInBytes,
          ),
          'width': image.width,
          'height': image.height,
        });
      } finally {
        image.dispose();
      }
    } finally {
      codec.dispose();
    }
  }

  Future<void> _sendImage(
    String method,
    Uint8List bytes,
    String extension,
  ) async {
    await _channel.invokeMethod<void>(method, {
      'bytes': bytes,
      'extension': extension,
    });
  }

  Future<String> saveImage(
    Uint8List bytes,
    String extension,
    String fileName,
  ) async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final path = await _channel.invokeMethod<String>('saveImage', {
        'bytes': bytes,
        'extension': extension,
        'fileName': fileName,
      });
      if (path == null || path.isEmpty) {
        throw StateError('The image was not saved');
      }
      return path;
    }

    final directory = Directory(
      '${File(Platform.resolvedExecutable).parent.path}/Saved_Images',
    );
    await directory.create(recursive: true);
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }
}
