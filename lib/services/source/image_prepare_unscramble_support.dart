part of '../hazuki_source_service.dart';

extension HazukiSourceServiceImagePrepareUnscrambleSupport
    on HazukiSourceService {
  String _imageExtensionFromUrl(String imageUrl) {
    final uri = Uri.tryParse(imageUrl);
    final lastSegment = uri?.pathSegments.isNotEmpty == true
        ? uri!.pathSegments.last
        : imageUrl.split('/').last;
    final match = RegExp(
      r'\.([a-zA-Z0-9]+)(?:$|\?)',
      caseSensitive: false,
    ).firstMatch(lastSegment);
    final ext = match?.group(1)?.toLowerCase();
    if (ext == null || ext.isEmpty) {
      return 'jpg';
    }
    return ext;
  }

  Future<({Uint8List bytes, String extension, double? aspectRatio})>
  _unscrambleJmImageBytes(
    Uint8List data,
    int segments, {
    required String fallbackExtension,
  }) async {
    final codec = await instantiateImageCodec(data);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final width = image.width;
    final height = image.height;
    final aspectRatio = height > 0 ? width / height : null;
    final src = await image.toByteData(format: ImageByteFormat.rawRgba);
    if (src == null) {
      return (
        bytes: data,
        extension: fallbackExtension,
        aspectRatio: aspectRatio,
      );
    }

    final blockSize = height ~/ segments;
    final remainder = height % segments;
    final srcBytes = src.buffer.asUint8List();
    final dstBytes = Uint8List(srcBytes.length);

    var destY = 0;
    for (var i = segments - 1; i >= 0; i--) {
      final startY = i * blockSize;
      final currentHeight = blockSize + (i == segments - 1 ? remainder : 0);
      final rowBytes = width * 4;
      for (var y = 0; y < currentHeight; y++) {
        final srcOffset = ((startY + y) * width) * 4;
        final dstOffset = ((destY + y) * width) * 4;
        dstBytes.setRange(dstOffset, dstOffset + rowBytes, srcBytes, srcOffset);
      }
      destY += currentHeight;
    }

    final buffer = await ImmutableBuffer.fromUint8List(dstBytes);
    final descriptor = ImageDescriptor.raw(
      buffer,
      width: width,
      height: height,
      pixelFormat: PixelFormat.rgba8888,
      rowBytes: width * 4,
    );
    final outCodec = await descriptor.instantiateCodec();
    final outFrame = await outCodec.getNextFrame();
    final png = await outFrame.image.toByteData(format: ImageByteFormat.png);
    if (png == null) {
      return (
        bytes: data,
        extension: fallbackExtension,
        aspectRatio: aspectRatio,
      );
    }
    return (
      bytes: png.buffer.asUint8List(),
      extension: 'png',
      aspectRatio: aspectRatio,
    );
  }
}
