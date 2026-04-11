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
    final fallbackSegments = calculateJmImageSegments(epId, imageUrl);
    final segments = declaredSegments != null && declaredSegments > 1
        ? declaredSegments
        : fallbackSegments;
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
}
