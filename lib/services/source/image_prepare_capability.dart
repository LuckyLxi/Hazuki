part of '../hazuki_source_service.dart';

class PreparedChapterImageData {
  const PreparedChapterImageData({
    required this.bytes,
    required this.extension,
    required this.wasProcessed,
  });

  final Uint8List bytes;
  final String extension;
  final bool wasProcessed;
}

extension HazukiSourceServiceImagePrepareCapability on HazukiSourceService {
  bool isLocalImagePath(String value) {
    final normalized = value.trim();
    return normalized.startsWith('/') || normalized.startsWith('file://');
  }

  String normalizeLocalImagePath(String value) {
    final normalized = value.trim();
    if (normalized.startsWith('file://')) {
      return Uri.parse(normalized).toFilePath();
    }
    return normalized;
  }

  int calculateJmImageSegments(String epId, String imageUrl) {
    const scrambleId = 220980;
    final id = int.tryParse(epId) ?? 0;
    if (id < scrambleId) {
      return 0;
    }
    if (id < 268850) {
      return 10;
    }

    final uri = Uri.tryParse(imageUrl);
    final last = uri?.pathSegments.isNotEmpty == true
        ? uri!.pathSegments.last
        : imageUrl.split('/').last;
    final pictureName = last.endsWith('.webp')
        ? last.substring(0, last.length - 5)
        : last;

    final digest = md5.convert(utf8.encode('$id$pictureName')).toString();
    final charCode = digest.codeUnitAt(digest.length - 1);

    if (id > 421926) {
      final remainder = charCode % 8;
      return remainder * 2 + 2;
    }
    final remainder = charCode % 10;
    return remainder * 2 + 2;
  }

  Future<PreparedChapterImageData> prepareChapterImageData(
    String imageUrl, {
    required String comicId,
    required String epId,
  }) async {
    final rawBytes = await downloadImageBytes(
      imageUrl,
      comicId: comicId,
      epId: epId,
      keepInMemory: false,
    );
    final segments = calculateJmImageSegments(epId, imageUrl);
    if (segments > 1 && !imageUrl.toLowerCase().endsWith('.gif')) {
      final fixed = await _unscrambleJmImageBytes(rawBytes, segments);
      return PreparedChapterImageData(
        bytes: fixed,
        extension: 'png',
        wasProcessed: true,
      );
    }
    return PreparedChapterImageData(
      bytes: rawBytes,
      extension: _imageExtensionFromUrl(imageUrl),
      wasProcessed: false,
    );
  }

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

  Future<Uint8List> _unscrambleJmImageBytes(
    Uint8List data,
    int segments,
  ) async {
    final codec = await instantiateImageCodec(data);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final width = image.width;
    final height = image.height;
    final src = await image.toByteData(format: ImageByteFormat.rawRgba);
    if (src == null) {
      return data;
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
        dstBytes.setRange(
          dstOffset,
          dstOffset + rowBytes,
          srcBytes,
          srcOffset,
        );
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
      return data;
    }
    return png.buffer.asUint8List();
  }
}
