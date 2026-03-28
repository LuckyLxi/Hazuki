part of '../hazuki_source_service.dart';

class PreparedChapterImageData {
  const PreparedChapterImageData({
    required this.bytes,
    required this.extension,
    required this.wasProcessed,
    this.aspectRatio,
  });

  final Uint8List bytes;
  final String extension;
  final bool wasProcessed;
  final double? aspectRatio;
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
    if ((_sourceMeta?.key ?? '').toLowerCase() != 'jm') {
      return 0;
    }

    const scrambleId = 220980;
    final id = int.tryParse(epId) ?? 0;
    if (id < scrambleId) {
      return 0;
    }
    if (id < 268850) {
      return 10;
    }

    final pictureName = _extractJmPictureName(imageUrl);
    final digest = md5.convert(utf8.encode('$id$pictureName')).toString();
    final charCode = digest.codeUnitAt(digest.length - 1);

    if (id > 421926) {
      final remainder = charCode % 8;
      return remainder * 2 + 2;
    }
    final remainder = charCode % 10;
    return remainder * 2 + 2;
  }

  String _extractJmPictureName(String imageUrl) {
    final normalizedUrl = imageUrl.trim();
    final slashIndex = normalizedUrl.lastIndexOf('/');
    final lastSegment = slashIndex >= 0
        ? normalizedUrl.substring(slashIndex + 1)
        : normalizedUrl;
    if (lastSegment.length > 5) {
      return lastSegment.substring(0, lastSegment.length - 5);
    }
    final dotIndex = lastSegment.lastIndexOf('.');
    if (dotIndex > 0) {
      return lastSegment.substring(0, dotIndex);
    }
    return lastSegment;
  }

  Future<int?> _resolveSourceDeclaredImageSegments(
    String imageUrl, {
    required String comicId,
    required String epId,
  }) async {
    try {
      final engine = _engine;
      if (engine == null) {
        return null;
      }
      final dynamic configRaw = engine.evaluate(
        'this.__hazuki_source.comic?.onImageLoad?.(${jsonEncode(imageUrl)}, ${jsonEncode(comicId)}, ${jsonEncode(epId)}) ?? {}',
        name: 'source_on_image_prepare.js',
      );
      final dynamic config = await _awaitJsResult(configRaw);
      if (config is! Map) {
        return null;
      }
      final modifyImage = config['modifyImage']?.toString().trim() ?? '';
      if (modifyImage.isEmpty) {
        return 0;
      }
      final match = RegExp(
        r'(?:const|let|var)\s+num\s*=\s*(\d+)\b',
      ).firstMatch(modifyImage);
      return int.tryParse(match?.group(1) ?? '');
    } catch (_) {
      return null;
    }
  }

  Future<PreparedChapterImageData> prepareChapterImageData(
    String imageUrl, {
    required String comicId,
    required String epId,
    bool useDiskCache = true,
  }) async {
    final rawBytes = await downloadImageBytes(
      imageUrl,
      comicId: comicId,
      epId: epId,
      keepInMemory: false,
      useDiskCache: useDiskCache,
    );
    final declaredSegments = await _resolveSourceDeclaredImageSegments(
      imageUrl,
      comicId: comicId,
      epId: epId,
    );
    final sourceExtension = _imageExtensionFromUrl(imageUrl);
    final segments =
        declaredSegments ?? calculateJmImageSegments(epId, imageUrl);
    if (segments > 1 && sourceExtension != 'gif') {
      final fixed = await _unscrambleJmImageBytes(
        rawBytes,
        segments,
        fallbackExtension: sourceExtension,
      );
      return PreparedChapterImageData(
        bytes: fixed.bytes,
        extension: fixed.extension,
        wasProcessed: true,
        aspectRatio: fixed.aspectRatio,
      );
    }
    return PreparedChapterImageData(
      bytes: rawBytes,
      extension: sourceExtension,
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
