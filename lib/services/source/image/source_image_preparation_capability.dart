import 'dart:convert';
import 'dart:ui';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../models/source_contract_models.dart';
import '../runtime/source_runtime_host.dart';

typedef SourceImageBytesDownloader =
    Future<Uint8List> Function(
      String url, {
      String? comicId,
      String? epId,
      bool keepInMemory,
      bool useDiskCache,
      bool priority,
      String sourceKey,
    });

/// Prepares source images without coupling the reader pipeline to the service
/// façade.
class SourceImagePreparationCapability {
  SourceImagePreparationCapability({
    required SourceRuntimeHost runtimeHost,
    required SourceImageBytesDownloader downloadImageBytes,
  }) : _runtimeHost = runtimeHost,
       _downloadImageBytes = downloadImageBytes;

  final SourceRuntimeHost _runtimeHost;
  final SourceImageBytesDownloader _downloadImageBytes;

  bool isLocalImagePath(String value) {
    final normalized = value.trim();
    if (normalized.startsWith('/') || normalized.startsWith('file://')) {
      return true;
    }
    return normalized.length >= 3 &&
        normalized[1] == ':' &&
        (normalized[2] == '\\' || normalized[2] == '/');
  }

  String normalizeLocalImagePath(String value) {
    final normalized = value.trim();
    return normalized.startsWith('file://')
        ? Uri.parse(normalized).toFilePath()
        : normalized;
  }

  int calculateJmImageSegments(
    String epId,
    String imageUrl, {
    String sourceKey = '',
  }) {
    final resolvedSourceKey = _resolveSourceKey(sourceKey);
    final sourceMetaKey = _runtimeHost
        .handleFor(resolvedSourceKey)
        .runtime
        .sourceMeta
        ?.key;
    return calculateJmImageSegmentsForSource(
      epId,
      imageUrl,
      sourceKey: sourceMetaKey,
    );
  }

  Future<PreparedChapterImageData> prepareChapterImageData(
    String imageUrl, {
    required String comicId,
    required String epId,
    bool useDiskCache = true,
    bool priority = false,
    String sourceKey = '',
  }) async {
    final rawBytes = await _downloadImageBytes(
      imageUrl,
      comicId: comicId,
      epId: epId,
      keepInMemory: false,
      useDiskCache: useDiskCache,
      priority: priority,
      sourceKey: sourceKey,
    );
    final declaredSegments = await _resolveSourceDeclaredImageSegments(
      imageUrl,
      comicId: comicId,
      epId: epId,
      sourceKey: sourceKey,
    );
    final sourceExtension = imageExtensionFromUrl(imageUrl);
    final fallbackSegments = calculateJmImageSegments(
      epId,
      imageUrl,
      sourceKey: sourceKey,
    );
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

  String _resolveSourceKey(String sourceKey) => sourceKey.trim().isEmpty
      ? _runtimeHost.activeSourceKey
      : _runtimeHost.normalize(sourceKey);

  Future<int?> _resolveSourceDeclaredImageSegments(
    String imageUrl, {
    required String comicId,
    required String epId,
    required String sourceKey,
  }) async {
    try {
      final facade = _runtimeHost
          .handleFor(_resolveSourceKey(sourceKey))
          .facade;
      final engine = facade.js.engine;
      if (engine == null) return null;
      final dynamic configRaw = engine.evaluate(
        'this.__hazuki_source.comic?.onImageLoad?.(${jsonEncode(imageUrl)}, ${jsonEncode(comicId)}, ${jsonEncode(epId)}) ?? {}',
        name: 'source_on_image_prepare.js',
      );
      return parseDeclaredImageSegments(await facade.js.resolve(configRaw));
    } catch (_) {
      return null;
    }
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
    try {
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
      final outImage = outFrame.image;
      try {
        final png = await outImage.toByteData(format: ImageByteFormat.png);
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
      } finally {
        outImage.dispose();
      }
    } finally {
      image.dispose();
    }
  }

  @visibleForTesting
  static int? parseDeclaredImageSegments(dynamic config) {
    if (config is! Map) return null;
    final directSegments = config['segments'] ?? config['num'];
    if (directSegments is num) return directSegments.toInt();
    final directSegmentsText = directSegments?.toString().trim() ?? '';
    if (directSegmentsText.isNotEmpty) {
      final parsed = int.tryParse(directSegmentsText);
      if (parsed != null) return parsed;
    }
    final modifyImage = config['modifyImage']?.toString().trim() ?? '';
    if (modifyImage.isEmpty) return null;
    final match = RegExp(r'\bnum\s*=\s*(\d+)\b').firstMatch(modifyImage);
    return int.tryParse(match?.group(1) ?? '');
  }

  @visibleForTesting
  static String imageExtensionFromUrl(String imageUrl) {
    final uri = Uri.tryParse(imageUrl);
    final lastSegment = uri?.pathSegments.isNotEmpty == true
        ? uri!.pathSegments.last
        : imageUrl.split('/').last;
    final match = RegExp(
      r'\.([a-zA-Z0-9]+)(?:$|\?)',
      caseSensitive: false,
    ).firstMatch(lastSegment);
    final extension = match?.group(1)?.toLowerCase();
    return extension == null || extension.isEmpty ? 'jpg' : extension;
  }

  @visibleForTesting
  static String extractJmPictureName(String imageUrl) {
    final normalizedUrl = imageUrl.trim();
    final uri = Uri.tryParse(normalizedUrl);
    final lastSegment = uri?.pathSegments.isNotEmpty == true
        ? uri!.pathSegments.last
        : normalizedUrl.split('/').last.split('?').first;
    final dotIndex = lastSegment.lastIndexOf('.');
    return dotIndex > 0 ? lastSegment.substring(0, dotIndex) : lastSegment;
  }

  @visibleForTesting
  static int calculateJmImageSegmentsForSource(
    String epId,
    String imageUrl, {
    String? sourceKey,
  }) {
    if ((sourceKey ?? '').toLowerCase() != 'jm') return 0;
    const scrambleId = 220980;
    final id = int.tryParse(epId) ?? 0;
    if (id < scrambleId) return 0;
    if (id < 268850) return 10;
    final digest = md5
        .convert(utf8.encode('$id${extractJmPictureName(imageUrl)}'))
        .toString();
    final charCode = digest.codeUnitAt(digest.length - 1);
    final remainder = id > 421926 ? charCode % 8 : charCode % 10;
    return remainder * 2 + 2;
  }
}
